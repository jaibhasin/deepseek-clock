//
//  StatusIcon.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Builds the menu bar choices and the whale in the panel header.                  │
//  │                                                                              │
//  │ WHY DRAW IT IN CODE?                                                          │
//  │ The shape is just a handful of Bézier curves, so drawing it ourselves means   │
//  │ no image asset to bundle, no file to go missing, and a crisp result at any    │
//  │ size. The path is authored in a 0…1 "unit box" and stretched into whatever    │
//  │ rectangle it is handed, so it scales cleanly from the 18pt menu bar glyph to  │
//  │ the 26pt popover header.                                                      │
//  │                                                                              │
//  │ Menu bar shapes are templates for native contrast. Coloured details are       │
//  │ separate images so AppKit does not flatten them.                              │
//  │                                                                              │
//  │ HOW THE WHALE IS ASSEMBLED                                                   │
//  │ The body, tail fluke and pectoral fin overlap and share one colour, so they   │
//  │ fuse into a solid silhouette. The water spout is drawn last in the state      │
//  │ colour so it reads as a little indicator light on top of the head.            │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import AppKit

enum StatusIcon {

    /// Returns a coloured whale glyph for the panel header.
    ///
    /// The body is drawn in the system menu bar foreground so it looks native in
    /// both light and dark mode; the spout carries the phase colour.
    ///
    /// - Parameter size: edge length in points. Menu bar glyphs are ~18pt tall.
    static func image(for phase: PricingPhase, size: CGFloat = 18) -> NSImage {
        let isDark = NSApp.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bodyColor: NSColor = isDark ? .white : .black

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            // A small margin so the whale does not touch the glyph edges.
            let box = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04)

            bodyColor.setFill()
            body(in: box).fill()
            tail(in: box).fill()
            fin(in: box).fill()

            phase.nsColor.setFill()
            spout(in: box).fill()

            return true
        }

        // No template flattening: we need to keep the coloured spout.
        image.isTemplate = false
        return image
    }

    /// The monochrome portion of a menu bar icon. AppKit chooses its foreground
    /// for the current menu bar appearance.
    static func menuBarImage(for style: MenuBarIconStyle = .spoutWhale,
                             size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let box = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04)
            NSColor.black.setFill()
            switch style {
            case .plainWhale:
                drawWhale(in: box)
                spout(in: box).fill()
            case .spoutWhale, .boldWhale:
                drawWhale(in: box)
            case .deepSeekPlain, .deepSeekTwoTone:
                drawOfficialWhale(in: box)
            case .tailSplash:
                splashTail(in: box).fill()
            case .oceanWave:
                wave(in: box).fill()
            case .hourglass:
                drawHourglass(in: box)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// A transparent, phase-coloured detail aligned with the template image.
    static func accentImage(for style: MenuBarIconStyle, phase: PricingPhase,
                            size: CGFloat = 18) -> NSImage? {
        guard style.showsPricingColor else { return nil }
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let box = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04)
            phase.nsColor.setFill()
            switch style {
            case .spoutWhale:
                spout(in: box).fill()
            case .boldWhale:
                NSGraphicsContext.saveGraphicsState()
                whale(in: box).addClip()
                let head = NSRect(x: box.minX, y: box.minY,
                                  width: box.width * 0.48, height: box.height)
                NSBezierPath(rect: head).fill()
                NSGraphicsContext.restoreGraphicsState()
                spout(in: box).fill()
            case .deepSeekTwoTone:
                drawOfficialAccent(in: box, color: phase.nsColor)
            case .tailSplash:
                splash(in: box).fill()
            case .oceanWave:
                waveCrest(in: box).fill()
            case .hourglass:
                hourglassSand(in: box).fill()
            case .plainWhale, .deepSeekPlain:
                break
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// The current icon's coloured component, kept for the existing status item.
    static func spoutImage(for phase: PricingPhase, size: CGFloat = 18) -> NSImage {
        accentImage(for: .spoutWhale, phase: phase, size: size)!
    }

    /// The PDF is cropped from DeepSeek's official logo SVG at
    /// https://github.com/deepseek-ai/DeepSeek-LLM/blob/main/images/logo.svg.
    private static let officialWhale: NSImage? = {
        let url = Bundle.main.url(forResource: "DeepSeekWhale", withExtension: "pdf")
            ?? Bundle.module.url(forResource: "DeepSeekWhale", withExtension: "pdf")
        return url.flatMap(NSImage.init(contentsOf:))
    }()

    static var hasOfficialArtwork: Bool { officialWhale != nil }

    private static func drawWhale(in rect: NSRect) {
        body(in: rect).fill()
        tail(in: rect).fill()
        fin(in: rect).fill()
    }

    private static func whale(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.append(body(in: rect))
        path.append(tail(in: rect))
        path.append(fin(in: rect))
        return path
    }

    private static func officialFrame(in rect: NSRect) -> NSRect {
        guard let officialWhale else { return rect }
        let aspect = officialWhale.size.width / officialWhale.size.height
        let width = min(rect.width, rect.height * aspect)
        let height = width / aspect
        return NSRect(x: rect.midX - width / 2, y: rect.midY - height / 2,
                      width: width, height: height)
    }

    private static func drawOfficialWhale(in rect: NSRect) {
        if let officialWhale {
            officialWhale.draw(in: officialFrame(in: rect))
        } else {
            drawWhale(in: rect)
        }
    }

    private static func drawOfficialAccent(in rect: NSRect, color: NSColor) {
        guard let officialWhale else { return }
        NSGraphicsContext.saveGraphicsState()
        let tailRegion = NSRect(x: rect.minX + rect.width * 0.65, y: rect.minY,
                                width: rect.width * 0.35, height: rect.height)
        NSBezierPath(rect: tailRegion).addClip()
        officialWhale.draw(in: officialFrame(in: rect))
        color.setFill()
        NSGraphicsContext.current?.compositingOperation = .sourceAtop
        NSBezierPath(rect: rect).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - The whale, built from overlapping shapes

    /// The rounded head-and-body blob. The dip on the right is the back, which the
    /// tail attaches to.
    private static func body(in rect: NSRect) -> NSBezierPath {
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
    private static func tail(in rect: NSRect) -> NSBezierPath {
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
    private static func fin(in rect: NSRect) -> NSBezierPath {
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
    /// are enough at this size and stay readable when shrunk to 18pt.
    private static func spout(in rect: NSRect) -> NSBezierPath {
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

    private static func splashTail(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let p = point(in: rect)
        path.move(to: p(0.50, 0.53))
        path.curve(to: p(0.07, 0.78), controlPoint1: p(0.37, 0.69),
                   controlPoint2: p(0.19, 0.84))
        path.curve(to: p(0.13, 0.48), controlPoint1: p(0.03, 0.69),
                   controlPoint2: p(0.05, 0.56))
        path.curve(to: p(0.50, 0.53), controlPoint1: p(0.29, 0.43),
                   controlPoint2: p(0.40, 0.48))
        path.close()
        path.move(to: p(0.50, 0.53))
        path.curve(to: p(0.93, 0.78), controlPoint1: p(0.63, 0.69),
                   controlPoint2: p(0.81, 0.84))
        path.curve(to: p(0.87, 0.48), controlPoint1: p(0.97, 0.69),
                   controlPoint2: p(0.95, 0.56))
        path.curve(to: p(0.50, 0.53), controlPoint1: p(0.71, 0.43),
                   controlPoint2: p(0.60, 0.48))
        path.close()
        path.appendRoundedRect(NSRect(x: p(0.43, 0).x, y: p(0, 0.22).y,
                                      width: rect.width * 0.14, height: rect.height * 0.35),
                               xRadius: rect.width * 0.05, yRadius: rect.width * 0.05)
        return path
    }

    private static func splash(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let p = point(in: rect)
        path.move(to: p(0.08, 0.16))
        path.curve(to: p(0.50, 0.19), controlPoint1: p(0.24, 0.27),
                   controlPoint2: p(0.36, 0.26))
        path.curve(to: p(0.92, 0.16), controlPoint1: p(0.64, 0.26),
                   controlPoint2: p(0.76, 0.27))
        path.line(to: p(0.92, 0.08))
        path.curve(to: p(0.50, 0.11), controlPoint1: p(0.75, 0.18),
                   controlPoint2: p(0.64, 0.18))
        path.curve(to: p(0.08, 0.08), controlPoint1: p(0.36, 0.18),
                   controlPoint2: p(0.25, 0.18))
        path.close()
        return path
    }

    private static func wave(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.append(waveBand(in: rect, y: 0.40))
        path.append(waveBand(in: rect, y: 0.19))
        return path
    }

    private static func waveCrest(in rect: NSRect) -> NSBezierPath {
        waveBand(in: rect, y: 0.61)
    }

    private static func waveBand(in rect: NSRect, y: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let p = point(in: rect)
        path.move(to: p(0.10, y))
        path.curve(to: p(0.50, y), controlPoint1: p(0.24, y + 0.20),
                   controlPoint2: p(0.35, y + 0.20))
        path.curve(to: p(0.90, y), controlPoint1: p(0.65, y - 0.20),
                   controlPoint2: p(0.76, y - 0.20))
        path.line(to: p(0.90, y - 0.10))
        path.curve(to: p(0.50, y - 0.10), controlPoint1: p(0.76, y - 0.30),
                   controlPoint2: p(0.65, y - 0.30))
        path.curve(to: p(0.10, y - 0.10), controlPoint1: p(0.35, y + 0.10),
                   controlPoint2: p(0.24, y + 0.10))
        path.close()
        return path
    }

    private static func drawHourglass(in rect: NSRect) {
        let frame = NSBezierPath()
        let p = point(in: rect)
        frame.lineWidth = rect.width * 0.075
        frame.lineCapStyle = .round
        frame.lineJoinStyle = .round
        frame.move(to: p(0.21, 0.84))
        frame.line(to: p(0.79, 0.84))
        frame.move(to: p(0.21, 0.16))
        frame.line(to: p(0.79, 0.16))
        frame.move(to: p(0.25, 0.82))
        frame.line(to: p(0.50, 0.51))
        frame.line(to: p(0.25, 0.18))
        frame.move(to: p(0.75, 0.82))
        frame.line(to: p(0.50, 0.51))
        frame.line(to: p(0.75, 0.18))
        frame.stroke()
    }

    private static func hourglassSand(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let p = point(in: rect)
        path.move(to: p(0.33, 0.22))
        path.line(to: p(0.67, 0.22))
        path.line(to: p(0.50, 0.43))
        path.close()
        path.appendRect(NSRect(x: p(0.48, 0).x, y: p(0, 0.46).y,
                               width: rect.width * 0.04, height: rect.height * 0.08))
        return path
    }

    /// Maps normalised 0…1 coordinates into `rect`, so one set of numbers can be
    /// reused at any icon size. `(0, 0)` is the bottom-left, `(1, 1)` the top-right.
    private static func point(in rect: NSRect) -> (CGFloat, CGFloat) -> NSPoint {
        { x, y in
            NSPoint(x: rect.minX + x * rect.width,
                    y: rect.minY + y * rect.height)
        }
    }
}
