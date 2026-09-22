//
//  StatusIcon.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Builds the little menu bar icon: a simple whale silhouette tinted GREEN       │
//  │ (off-peak) or RED (peak).                                                     │
//  │                                                                              │
//  │ WHY DRAW IT IN CODE?                                                          │
//  │ The shape is just a handful of Bézier curves, so drawing it ourselves means   │
//  │ no image asset to bundle, no file to go missing, and a crisp result at any    │
//  │ size. The path is authored in a 0…1 "unit box" and stretched into whatever    │
//  │ rectangle it is handed, so it scales cleanly from 18pt menu bar glyph to the  │
//  │ 26pt popover header.                                                          │
//  │                                                                              │
//  │ WHY TINT MANUALLY?                                                            │
//  │ macOS renders "template" images as flat monochrome — that is why most menu    │
//  │ bar glyphs follow the light/dark system colour. To keep the green/red         │
//  │ meaning we must turn templating OFF and colour the pixels ourselves.          │
//  │                                                                              │
//  │ HOW THE SILHOUETTE IS ASSEMBLED                                              │
//  │   1. draw the rounded body                                                    │
//  │   2. add the two-lobed tail fluke on top                                      │
//  │   3. add the little pectoral fin underneath                                   │
//  │ All three shapes overlap and are filled with the same colour, so they fuse    │
//  │ into one solid whale silhouette.                                              │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import AppKit

enum StatusIcon {

    /// Returns a coloured, menu-bar-ready image for `phase`.
    ///
    /// - Parameter size: edge length in points. Menu bar glyphs are ~18pt tall.
    static func image(for phase: PricingPhase, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            phase.nsColor.setFill()
            // A little breathing room so the whale does not touch the glyph edges.
            let box = rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.12)
            bodyPath(in: box).fill()
            tailPath(in: box).fill()
            finPath(in: box).fill()
            return true
        }

        // `isTemplate = false` is the crucial line: it tells macOS "do NOT
        // recolour this for me" so our green/red survives into the menu bar.
        image.isTemplate = false
        return image
    }

    // MARK: - The whale, built from three overlapping shapes

    /// The rounded head-and-body blob. The small dip near the right is the back,
    /// which the tail attaches to.
    private static func bodyPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let p: (CGFloat, CGFloat) -> NSPoint = point(in: rect)

        path.move(to: p(0.06, 0.50))                         // nose (left tip)
        path.curve(to: p(0.46, 0.78),                        // over the top of the head
                   controlPoint1: p(0.10, 0.80),
                   controlPoint2: p(0.28, 0.82))
        path.curve(to: p(0.70, 0.60),                        // slight hump, then back
                   controlPoint1: p(0.60, 0.76),
                   controlPoint2: p(0.70, 0.68))
        path.curve(to: p(0.64, 0.34),                        // down the rear of the body
                   controlPoint1: p(0.70, 0.50),
                   controlPoint2: p(0.68, 0.40))
        path.curve(to: p(0.06, 0.50),                        // along the belly to the nose
                   controlPoint1: p(0.34, 0.20),
                   controlPoint2: p(0.10, 0.26))
        path.close()
        return path
    }

    /// The tail: two solid triangular lobes meeting at a notch, exactly the way a
    /// whale fluke is drawn in its simplest pictogram form.
    private static func tailPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let p = point(in: rect)

        path.move(to: p(0.60, 0.58))                         // attach to the upper back
        path.curve(to: p(0.97, 0.72),                        // sweep out to the top tip
                   controlPoint1: p(0.78, 0.64),
                   controlPoint2: p(0.90, 0.72))
        path.line(to: p(0.82, 0.50))                         // in to the central notch
        path.line(to: p(0.97, 0.28))                         // back out to the bottom tip
        path.curve(to: p(0.60, 0.42),                        // sweep in to the lower back
                   controlPoint1: p(0.90, 0.28),
                   controlPoint2: p(0.78, 0.36))
        path.close()
        return path
    }

    /// The small pectoral fin hanging under the body.
    private static func finPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let p = point(in: rect)

        path.move(to: p(0.50, 0.38))
        path.curve(to: p(0.44, 0.12),                        // down to the fin tip
                   controlPoint1: p(0.52, 0.30),
                   controlPoint2: p(0.48, 0.14))
        path.curve(to: p(0.31, 0.28),                        // back up into the body
                   controlPoint1: p(0.35, 0.12),
                   controlPoint2: p(0.33, 0.20))
        path.close()
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
