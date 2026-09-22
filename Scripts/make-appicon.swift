//
//  make-appicon.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Builds `Resources/AppIcon.icns`, the artwork macOS shows in the Finder,       │
//  │ Dock and About box, from the single source image `DeepSeekLogo.png`.          │
//  │                                                                              │
//  │ WHY A SCRIPT?                                                                │
//  │ Mac app icons are not one image — they are a set of PNGs at fixed sizes      │
//  │ (16…1024 px) packaged into a `.icns`. Rather than check ten resized PNGs      │
//  │ into Git, we draw each size on demand from the logo, so there is exactly one │
//  │ source of truth and the result is reproducible.                              │
//  │                                                                              │
//  │ HOW TO RUN (from the repository root, on macOS):                             │
//  │                                                                              │
//  │     swift Scripts/make-appicon.swift                                         │
//  │                                                                              │
//  │ WHAT IT DOES                                                                 │
//  │   1. draws a rounded-rectangle ("squircle") tile with a blue gradient        │
//  │   2. tints the navy whale white and centres it on the tile                   │
//  │   3. renders the tile at every required size into `AppIcon.iconset/`         │
//  │   4. hands that folder to Apple's `iconutil` to produce `AppIcon.icns`       │
//  └──────────────────────────────────────────────────────────────────────────────┘
//

import AppKit

// MARK: - Paths

// Resolve everything relative to the current working directory (the repo root),
// so the script behaves the same no matter where the user's shell is pointed.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let logoURL = resources.appendingPathComponent("DeepSeekLogo.png")
let iconsetURL = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resources.appendingPathComponent("AppIcon.icns")

guard let logo = NSImage(contentsOf: logoURL) else {
    FileHandle.standardError.write(Data("error: cannot read \(logoURL.path)\n".utf8))
    exit(1)
}

// MARK: - The icon's look

/// Colours for the background gradient. DeepSeek's brand blue, light at the top
/// fading to a deeper blue at the bottom for a little depth.
let topBlue = NSColor(calibratedRed: 0.13, green: 0.42, blue: 0.91, alpha: 1)
let bottomBlue = NSColor(calibratedRed: 0.05, green: 0.19, blue: 0.58, alpha: 1)

/// macOS icons leave a transparent margin around the artwork; ~9% per side matches
/// the visual weight of system icons.
let paddingFraction: CGFloat = 0.09

/// Corner radius as a fraction of the tile's width. Apple's "squircle" is roughly
/// 22.4% — using a plain rounded rect at this radius reads as native.
let cornerFraction: CGFloat = 0.2245

/// The whale occupies this fraction of the tile's width, leaving comfortable
/// breathing room inside the rounded background.
let whaleFraction: CGFloat = 0.62

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
        NSGradient(starting: topBlue, ending: bottomBlue)?.draw(in: shape, angle: -90)

        // 2. White whale, centred on the tile. `sourceAtop` repaints only the
        //    pixels the logo already made opaque, turning the silhouette white
        //    while leaving its transparent surroundings untouched.
        let whaleSide = tile.width * whaleFraction
        let whaleRect = NSRect(
            x: tile.midX - whaleSide / 2,
            y: tile.midY - whaleSide / 2,
            width: whaleSide,
            height: whaleSide
        )
        let whiteWhale = NSImage(size: whaleRect.size, flipped: false) { whaleDrawingRect in
            logo.draw(in: whaleDrawingRect, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor.white.set()
            whaleDrawingRect.fill(using: .sourceAtop)
            return true
        }
        whiteWhale.draw(in: whaleRect, from: .zero, operation: .sourceOver, fraction: 1)

        return true
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

// Keep the working tree clean for Git: the .iconset is regenerated, the .icns is
// committed so builds do not depend on running this script.
print("Wrote \(icnsURL.path)")
