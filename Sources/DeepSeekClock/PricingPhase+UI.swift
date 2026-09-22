//
//  PricingPhase+UI.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Everything cosmetic about a pricing phase lives here, kept OUT of the pure   │
//  │ rule engine (`DeepSeekSchedule.swift`).                                      │
//  │                                                                              │
//  │ This is an `extension`, so the enum itself stays tiny while the UI layer      │
//  │ decides how a phase should look. If we ever redesign the icon or wording,    │
//  │ the business logic never has to change.                                       │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
//  COLOR CONVENTION (from docs/PRODUCT.md)
//  ---------------------------------------
//      off-peak = GREEN  (cheap, good time to run jobs)
//      peak     = RED    (full price, consider waiting)
//
import SwiftUI
import AppKit

extension PricingPhase {

    /// A hand-picked emerald green for off-peak. The system `.green` reads a bit
    /// harsh/neon; this shade is deeper and calmer, and still clearly signals
    /// "cheap, good time to run jobs".
    static let offPeakGreen = Color(red: 0.13, green: 0.72, blue: 0.40)

    /// The brand colour for this phase. Used by both the menu bar icon and the
    /// dropdown, so the two can never disagree.
    var color: Color {
        switch self {
        case .peak:    return .red
        case .offPeak: return Self.offPeakGreen
        }
    }

    /// The same colour as an AppKit value, needed to tint the `NSImage` that is
    /// drawn into the menu bar (AppKit works in `NSColor`, SwiftUI in `Color`).
    var nsColor: NSColor {
        NSColor(color)
    }

    /// Big heading shown at the top of the dropdown.
    var title: String {
        switch self {
        case .peak:    return "DeepSeek peak pricing"
        case .offPeak: return "DeepSeek off-peak pricing"
        }
    }

    /// Small sub-heading: what the price means in plain English.
    var subtitle: String {
        switch self {
        case .peak:    return "Standard rates"
        case .offPeak: return "50% cheaper"
        }
    }

    /// Label in front of the live countdown, phrased from the user's point of
    /// view: "how long until the price changes?"
    var changeLabel: String {
        switch self {
        case .peak:    return "Standard rates end in"
        case .offPeak: return "Off-peak ends in"
        }
    }
}
