//
//  DisplayTimeZone.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Which time zone the app *displays* transition times in.                      │
//  │                                                                              │
//  │ DeepSeek always bills in UTC, so peak/off-peak never depends on this value.   │
//  │ It only changes the wall-clock time shown for the next transition: a user in  │
//  │ India can watch their own clock, or deliberately follow a different country.  │
//  │                                                                              │
//  │ A `nil` identifier means "follow the Mac's system time zone" and is the      │
//  │ default, so existing behaviour is unchanged.                                 │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import Foundation

/// A user-selectable time zone for displaying transition times.
///
/// Pure value type: no UI, no timers, no persistence. `ClockModel` owns the
/// preference and stores it; this type only knows how to turn a stored
/// identifier into a usable `TimeZone` and a readable label.
struct DisplayTimeZone: Equatable {
    /// The stored zone identifier, or `nil` to follow the system zone.
    let identifier: String?

    /// Follow whatever time zone the Mac is set to right now.
    static let system = DisplayTimeZone(identifier: nil)

    /// `true` when following the system zone.
    var isSystem: Bool { identifier == nil }

    /// The concrete zone used for formatting.
    ///
    /// Unknown identifiers (for example a zone removed by an OS update) safely
    /// fall back to the system zone rather than crashing or showing nothing.
    var timeZone: TimeZone {
        guard let identifier, let zone = TimeZone(identifier: identifier) else {
            return .autoupdatingCurrent
        }
        return zone
    }

    /// Label for the current selection, e.g. "System (Asia/Kolkata)".
    var displayName: String {
        if isSystem {
            let city = TimeZone.autoupdatingCurrent.identifier
                .replacingOccurrences(of: "_", with: " ")
            return "System (\(city))"
        }
        return Self.label(for: timeZone)
    }

    /// Every zone the user can pick, sorted so the list is easy to scan.
    static var selectableIdentifiers: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    /// A readable label with the zone's current UTC offset, e.g.
    /// "Asia/Kolkata (GMT+5:30)".
    static func label(for zone: TimeZone) -> String {
        let city = zone.identifier.replacingOccurrences(of: "_", with: " ")
        return "\(city) (\(offsetLabel(zone)))"
    }

    /// Formats a zone's current UTC offset as "GMT+5:30" / "GMT-5:00".
    static func offsetLabel(_ zone: TimeZone) -> String {
        let seconds = zone.secondsFromGMT()
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds)
        return String(format: "GMT%@%d:%02d", sign, magnitude / 3600, (magnitude % 3600) / 60)
    }
}
