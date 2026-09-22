//
//  StatusIcon.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Builds the little menu bar icon: the DeepSeek whale tinted GREEN (off-peak)  │
//  │ or RED (peak).                                                               │
//  │                                                                              │
//  │ WHY TINT MANUALLY?                                                           │
//  │ macOS renders "template" images as flat monochrome — that is why most menu    │
//  │ bar glyphs follow the light/dark system colour. To keep the green/red         │
//  │ meaning we must turn templating OFF and colour the pixels ourselves.         │
//  │                                                                              │
//  │ HOW TINTING WORKS                                                            │
//  │   1. draw the whale into an off-screen image                                │
//  │   2. flood the whole area with the tint using `.sourceAtop`                  │
//  │ `sourceAtop` paints ONLY where the destination is already opaque, so the     │
//  │ transparent background stays transparent and the whale becomes a crisp       │
//  │ solid-colour silhouette.                                                     │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import AppKit

enum StatusIcon {

    /// Returns a coloured, menu-bar-ready image for `phase`.
    ///
    /// - Parameter size: edge length in points. Menu bar glyphs are ~18pt tall.
    static func image(for phase: PricingPhase, size: CGFloat = 18) -> NSImage {
        let base = logo() ?? fallbackSymbol()

        let tinted = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            phase.nsColor.set()
            rect.fill(using: .sourceAtop)
            return true
        }

        // `isTemplate = false` is the crucial line: it tells macOS "do NOT
        // recolour this for me" so our green/red survives into the menu bar.
        tinted.isTemplate = false
        return tinted
    }

    /// Loads the bundled DeepSeek whale (`Resources/DeepSeekLogo.png`, copied
    /// into the .app by `build.sh`). Returns `nil` when running an un-bundled
    /// binary (e.g. `swift run`), which lets us fall back gracefully.
    private static func logo() -> NSImage? {
        NSImage(named: "DeepSeekLogo")
    }

    /// Fallback if the logo asset is missing: a built-in SF Symbol so the app
    /// still shows a coloured, meaningful icon instead of nothing.
    private static func fallbackSymbol() -> NSImage {
        NSImage(systemSymbolName: "fish.fill", accessibilityDescription: "DeepSeek")!
    }
}
