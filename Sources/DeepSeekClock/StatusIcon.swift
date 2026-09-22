//
//  StatusIcon.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Builds the little menu bar glyph: a whale whose body matches the system's      │
//  │ menu bar foreground (black on a light bar, white on a dark one) while the      │
//  │ water spout on its head is tinted GREEN (off-peak) or RED (peak).              │
//  │                                                                              │
//  │ WHY DRAW IT IN CODE?                                                          │
//  │ The shape is just a handful of Bézier curves, so drawing it ourselves means   │
//  │ no image asset to bundle, no file to go missing, and a crisp result at any    │
//  │ size. The path is authored in a 0…1 "unit box" and stretched into whatever    │
//  │ rectangle it is handed, so it scales cleanly from the 18pt menu bar glyph to  │
//  │ the 26pt popover header.                                                      │
//  │                                                                              │
//  │ WHY NOT A TEMPLATE IMAGE?                                                     │
//  │ Template images are flattened by macOS to a single colour, which would erase  │
//  │ the red/green spout. So we draw the whale ourselves, choosing black or white  │
//  │ to match the current appearance, and paint the spout in the phase colour.     │
//  │ The image therefore has to be rebuilt when the theme or the phase changes     │
//  │ (see `DeepSeekClockApp.paint()`).                                             │
//  │                                                                              │
//  │ HOW THE WHALE IS ASSEMBLED                                                   │
//  │ The body, tail fluke and pectoral fin overlap and share one colour, so they   │
//  │ fuse into a solid silhouette. The water spout is drawn last in the state      │
//  │ colour so it reads as a little indicator light on top of the head.            │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import AppKit

enum StatusIcon {

    /// Returns a menu-bar-ready whale glyph for `phase` at `size` points.
    ///
    /// The body is drawn in the system menu bar foreground so it looks native in
    /// both light and dark mode; the spout carries the phase colour.
    ///
    /// - Parameter size: edge length in points. Menu bar glyphs are ~18pt tall.
    static func image(for phase: PricingPhase, size: CGFloat = 18) -> NSImage {
        // Match the menu bar: black glyph on a light bar, white on a dark one.
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

        drop(0.20, 0.62, 0.11, 0.30)                         // central plume
        drop(0.11, 0.72, 0.055, 0.12)                        // left droplet
        drop(0.29, 0.72, 0.055, 0.12)                        // right droplet
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
