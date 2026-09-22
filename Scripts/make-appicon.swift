//
//  make-appicon.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Builds `Resources/AppIcon.icns`, the artwork macOS shows in the Finder,       │
//  │ Dock and About box.                                                          │
//  │                                                                              │
//  │ WHY A SCRIPT?                                                                │
//  │ Mac app icons are not one image — they are a set of PNGs at fixed sizes      │
//  │ (16…1024 px) packaged into a `.icns`. Rather than check ten resized PNGs      │
//  │ into Git, we DRAW each size on demand, so there is exactly one source of      │
//  │ truth (this file) and the result is reproducible.                            │
//  │                                                                              │
//  │ WHY DRAW THE WHALE IN CODE (NOT A LOGO PNG)?                                 │
//  │ The menu bar glyph is itself drawn in code (`StatusIcon.swift`), so reusing   │
//  │ the same Bézier shapes here keeps the app icon and the menu bar icon looking  │
//  │ like the same character. No bitmap to keep in sync, and every size stays      │
//  │ crisp because we render fresh at each resolution.                             │
//  │                                                                              │
//  │ THE LOOK: a funky neon squircle (pink → violet → cyan) with the white whale   │
//  │ and its sunshine-yellow spout, so the icon feels playful while still reading  │
//  │ as "the DeepSeek clock whale".                                                │
//  │                                                                              │
//  │ HOW TO RUN (from the repository root, on macOS):                             │
//  │                                                                              │
//  │     swift Scripts/make-appicon.swift                                         │
//  │                                                                              │
//  │ WHAT IT DOES                                                                 │
//  │   1. draws a rounded-rectangle ("squircle") tile with a funky gradient        │
//  │   2. draws the whale silhouette + yellow spout centred on the tile            │
//  │   3. renders the tile at every required size into `AppIcon.iconset/`          │
//  │   4. hands that folder to Apple's `iconutil` to produce `AppIcon.icns`        │
//  │   5. also writes a 2048 px `AppIcon-2048.png` master for docs/marketing,      │
//  │      since macOS itself never uses anything larger than 1024 px.              │
//  └──────────────────────────────────────────────────────────────────────────────┘
//

import AppKit

// MARK: - Paths

// Resolve everything relative to the current working directory (the repo root),
// so the script behaves the same no matter where the user's shell is pointed.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resources.appendingPathComponent("AppIcon.icns")
let masterURL = resources.appendingPathComponent("AppIcon-2048.png")

// MARK: - The icon's look

/// Background gradient stops, drawn top-left to bottom-right. A hot pink fading
/// through electric violet into cyan — loud on purpose, so the icon pops in the
/// Dock and Finder next to utility apps.
let gradientPink = NSColor(srgbRed: 1.00, green: 0.13, blue: 0.55, alpha: 1)
let gradientViolet = NSColor(srgbRed: 0.55, green: 0.15, blue: 0.98, alpha: 1)
let gradientCyan = NSColor(srgbRed: 0.00, green: 0.83, blue: 0.98, alpha: 1)

/// The whale silhouette: clean white reads best against the saturated background.
let whaleWhite = NSColor.white

/// The spout keeps its role as the "indicator" from the menu bar, but in a fun
/// sunshine yellow instead of the red/green peak/off-peak states.
let spoutYellow = NSColor(srgbRed: 1.00, green: 0.89, blue: 0.30, alpha: 1)

/// macOS icons leave a transparent margin around the artwork; ~9% per side matches
/// the visual weight of system icons.
let paddingFraction: CGFloat = 0.09

/// Corner radius as a fraction of the tile's width. Apple's "squircle" is roughly
/// 22.4% — using a plain rounded rect at this radius reads as native.
let cornerFraction: CGFloat = 0.2245

/// The whale occupies this fraction of the tile's width, leaving comfortable
/// breathing room inside the rounded background.
let whaleFraction: CGFloat = 0.64

/// Draws the finished icon at `pixels` × `pixels`.
///
/// Rendering a fresh image for each size (instead of scaling one bitmap) lets
/// AppKit pick the best interpolation at small sizes, so the 16 px version stays
/// legible.
func drawIcon(pixels: Int) -> NSImage {
    let side = CGFloat(pixels)

    return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
        // 1. Rounded background tile.
        let tile = rect.insetBy(dx: side * paddingFraction, dy: side * paddingFraction)
        let radius = tile.width * cornerFraction
        let shape = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
        NSGradient(colors: [gradientPink, gradientViolet, gradientCyan])?
            .draw(in: shape, angle: -45)

        // Everything below is clipped to the tile so the whale's shadow cannot
        // spill into the transparent margin.
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()

        // 2. A faint inner stroke around the tile — the "sticker" outline that
        //    makes the flat colour feel like a physical object.
        let strokeWidth = max(1, side * 0.012)
        let inner = NSBezierPath(
            roundedRect: tile.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2),
            xRadius: radius - strokeWidth / 2,
            yRadius: radius - strokeWidth / 2
        )
        inner.lineWidth = strokeWidth
        NSColor.white.withAlphaComponent(0.22).setStroke()
        inner.stroke()

        // 3. The whale itself, centred on the tile.
        let whaleSide = tile.width * whaleFraction
        let whaleRect = NSRect(
            x: tile.midX - whaleSide / 2,
            y: tile.midY - whaleSide / 2,
            width: whaleSide,
            height: whaleSide
        )
        drawWhale(in: whaleRect)

        NSGraphicsContext.restoreGraphicsState()
        return true
    }
}

// MARK: - The whale

/// Paints the whale silhouette and its spout inside `rect`.
///
/// The body, tail and fin are separate paths sharing one fill colour, so they fuse
/// into a single solid silhouette; the spout is painted last in yellow so it reads
/// as a bright plume above the head. A soft shadow is dropped first to lift the
/// whale off the gradient.
func drawWhale(in rect: NSRect) {
    // Soft drop shadow: one combined silhouette nudged down a touch.
    let silhouette = NSBezierPath()
    silhouette.append(bodyPath(in: rect))
    silhouette.append(tailPath(in: rect))
    silhouette.append(finPath(in: rect))

    NSGraphicsContext.saveGraphicsState()
    let drop = NSAffineTransform()
    drop.translateX(by: 0, yBy: -rect.height * 0.035)
    drop.concat()
    NSColor.black.withAlphaComponent(0.18).setFill()
    silhouette.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Body + tail + fin in white, the spout in yellow.
    whaleWhite.setFill()
    bodyPath(in: rect).fill()
    tailPath(in: rect).fill()
    finPath(in: rect).fill()

    spoutYellow.setFill()
    spoutPath(in: rect).fill()
}

// These four shapes mirror `StatusIcon.swift` so the app icon and the menu bar
// glyph are unmistakably the same whale. Each is authored in a 0…1 "unit box" and
// stretched into `rect`, so it scales cleanly from 16 px to 1024 px.

/// The rounded head-and-body blob. The dip on the right is the back, which the
/// tail attaches to.
func bodyPath(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    let p = point(in: rect)

    path.move(to: p(0.06, 0.44))                         // nose (left tip)
    path.curve(to: p(0.44, 0.66),                        // over the top of the head
               controlPoint1: p(0.10, 0.68),
               controlPoint2: p(0.26, 0.70))
    path.curve(to: p(0.68, 0.50),                        // back, sloping to the tail
               controlPoint1: p(0.58, 0.64),
               controlPoint2: p(0.68, 0.58))
    path.curve(to: p(0.62, 0.28),                        // down the rear of the body
               controlPoint1: p(0.68, 0.40),
               controlPoint2: p(0.66, 0.34))
    path.curve(to: p(0.06, 0.44),                        // along the belly to the nose
               controlPoint1: p(0.32, 0.16),
               controlPoint2: p(0.10, 0.22))
    path.close()
    return path
}

/// The tail: two solid triangular lobes meeting at a notch, the simplest way a
/// whale fluke is drawn in a pictogram.
func tailPath(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    let p = point(in: rect)

    path.move(to: p(0.58, 0.50))                         // attach to the upper back
    path.curve(to: p(0.93, 0.64),                        // sweep out to the top tip
               controlPoint1: p(0.76, 0.56),
               controlPoint2: p(0.87, 0.64))
    path.line(to: p(0.79, 0.45))                         // in to the central notch
    path.line(to: p(0.94, 0.26))                         // back out to the bottom tip
    path.curve(to: p(0.58, 0.38),                        // sweep in to the lower back
               controlPoint1: p(0.87, 0.26),
               controlPoint2: p(0.76, 0.32))
    path.close()
    return path
}

/// The small pectoral fin hanging under the body.
func finPath(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    let p = point(in: rect)

    path.move(to: p(0.46, 0.32))
    path.curve(to: p(0.40, 0.10),                        // down to the fin tip
               controlPoint1: p(0.48, 0.26),
               controlPoint2: p(0.44, 0.12))
    path.curve(to: p(0.28, 0.24),                        // back up into the body
               controlPoint1: p(0.32, 0.10),
               controlPoint2: p(0.30, 0.17))
    path.close()
    return path
}

/// The water spout: a tall central plume with a droplet either side. Ellipses
/// are enough at this size and stay readable when shrunk to 16 px.
func spoutPath(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    let p = point(in: rect)

    // A filled ellipse from a normalised centre + size.
    func drop(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        let origin = p(cx - w / 2, cy)
        let size = NSSize(width: w * rect.width, height: h * rect.height)
        path.appendOval(in: NSRect(origin: origin, size: size))
    }

    drop(0.20, 0.61, 0.13, 0.34)                         // central plume
    drop(0.105, 0.71, 0.065, 0.14)                       // left droplet
    drop(0.295, 0.71, 0.065, 0.14)                       // right droplet
    return path
}

/// Maps normalised 0…1 coordinates into `rect`, so one set of numbers can be
/// reused at any icon size. `(0, 0)` is the bottom-left, `(1, 1)` the top-right.
func point(in rect: NSRect) -> (CGFloat, CGFloat) -> NSPoint {
    { x, y in
        NSPoint(x: rect.minX + x * rect.width,
                y: rect.minY + y * rect.height)
    }
}

// MARK: - PNG output

/// Renders `image` into an exactly `pixels` × `pixels` PNG at `url`.
func writePNG(_ image: NSImage, pixels: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "make-appicon", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "cannot allocate \(pixels)px bitmap"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make-appicon", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "cannot encode PNG"])
    }
    try data.write(to: url)
}

// MARK: - Build the iconset

// The exact filenames `iconutil` expects. The `@2x` entries are the Retina
// variants of the base size.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for variant in variants {
    let out = iconsetURL.appendingPathComponent(variant.name)
    try writePNG(drawIcon(pixels: variant.pixels), pixels: variant.pixels, to: out)
}

// MARK: - Pack the iconset into a .icns

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("error: iconutil failed\n".utf8))
    exit(1)
}

// The intermediate iconset is a build artefact, not something we keep around.
try? FileManager.default.removeItem(at: iconsetURL)

// A 2048 px master for the README, release notes and anywhere else that wants
// more pixels than the OS ever asks for. It is not used by the app itself.
let masterPixels = 2048
try writePNG(drawIcon(pixels: masterPixels), pixels: masterPixels, to: masterURL)

// Keep the working tree clean for Git: the .iconset is regenerated, the .icns and
// master PNG are committed so builds do not depend on running this script.
print("Wrote \(icnsURL.path)")
print("Wrote \(masterURL.path)")
