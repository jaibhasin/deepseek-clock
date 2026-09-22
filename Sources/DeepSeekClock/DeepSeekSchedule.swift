//
//  DeepSeekSchedule.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Pure business logic: "Is DeepSeek charging peak prices right now, and when   │
//  │ does that change?"                                                            │
//  │                                                                               │
//  │ This file deliberately contains NO SwiftUI, NO timers and NO UI state. That   │
//  │ separation matters: because the rules are pure functions of a `Date`, they    │
//  │ are trivial to reason about and could be unit-tested without launching a UI.  │
//  └───────────────────────────────────────────────────────────────────────────────┘
//
//  THE RULES (source: https://api-docs.deepseek.com/quick_start/pricing)
//  -------------------------------------------------------------------
//  • DeepSeek bills API usage in UTC.
//  • PEAK (full price) hours are:
//        01:00–04:00 UTC   and   06:00–10:00 UTC
//    on Monday through Friday only.
//  • Everything else is OFF-PEAK and costs 50% less — including the whole
//    weekend and (per DeepSeek) Chinese public holidays.
//
//  NOTE ON SCOPE: Chinese public holidays move every year and would need a
//  lookup table. To keep this app minimal we do NOT model them yet; holidays
//  will currently be shown as peak if they fall in a weekday window. That is
//  the one intentional simplification.
//
import Foundation

/// The two pricing phases DeepSeek can be in at any given moment.
///
/// An `enum` is the right tool here because a phase is one of a fixed set of
/// possibilities. It also lets us hang the UI's presentation strings right next
/// to the data, so the views stay dumb and this stays the single source of truth.
enum PricingPhase: Equatable {
    /// Full price (DeepSeek's documentation calls this "peak").
    case peak

    /// 50% discount (all hours outside the peak windows).
    case offPeak

    // MARK: - Presentation helpers (UI text + SF Symbol names)

    /// Big heading shown at the top of the dropdown.
    var title: String {
        switch self {
        case .peak:    return "DeepSeek peak pricing"
        case .offPeak: return "DeepSeek off-peak pricing"
        }
    }

    /// Small grey sub-heading: what the price means in plain English.
    var subtitle: String {
        switch self {
        case .peak:    return "Standard rates"
        case .offPeak: return "50% cheaper"
        }
    }

    /// Label in front of the live countdown.
    /// Phrased from the user's perspective: "how long until the price changes?"
    var changeLabel: String {
        switch self {
        case .peak:    return "Standard rates end in"
        case .offPeak: return "Off-peak ends in"
        }
    }

    /// Name of the SF Symbol drawn next to the heading (fire = peak, leaf = cheap).
    var symbol: String {
        switch self {
        case .peak:    return "flame.fill"
        case .offPeak: return "leaf.fill"
        }
    }
}

/// Computes pricing phases and phase-change times from a `Date`.
///
/// It is a `struct` (value type) with no mutable state, so a single instance can
/// safely be called over and over from the timer in `ClockModel`.
struct DeepSeekSchedule {

    /// Peak windows expressed as `[startHour, endHour)` in 24-hour UTC.
    /// `1..<4` means 01:00:00 up to (but not including) 04:00:00.
    static let peakWindows: [Range<Int>] = [1..<4, 6..<10]

    /// A calendar fixed to UTC so the rules never shift with the user's local
    /// time zone. `Calendar` handles leap years, month lengths, etc. for us.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// `true` when `date` falls inside a weekday peak window.
    ///
    /// `Calendar` weekdays are 1 = Sunday … 7 = Saturday, so Monday–Friday is
    /// the range `2...6`.
    func isPeak(at date: Date) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour else { return false }

        // Weekends are always off-peak.
        guard (2...6).contains(weekday) else { return false }

        // Peak if any window contains the current hour.
        return Self.peakWindows.contains { $0.contains(hour) }
    }

    /// The exact moment the phase next flips (peak → off-peak or vice versa).
    ///
    /// Strategy: collect every window boundary (both start and end, every
    /// weekday) for the next 9 days, then return the earliest one after `date`.
    /// Nine days is more than one full week, which guarantees we always find a
    /// boundary — e.g. after Friday's 10:00 end the next flip is Monday 01:00.
    func nextTransition(after date: Date) -> Date? {
        let startOfToday = calendar.startOfDay(for: date)
        var boundaries: [Date] = []

        for dayOffset in 0..<9 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
                continue
            }
            // Skip Saturday (7) and Sunday (1): no transitions happen on them,
            // because no window starts or ends on a weekend day.
            let weekday = calendar.component(.weekday, from: day)
            guard (2...6).contains(weekday) else { continue }

            for window in Self.peakWindows {
                for hour in [window.lowerBound, window.upperBound] {
                    if let instant = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) {
                        boundaries.append(instant)
                    }
                }
            }
        }

        return boundaries.filter { $0 > date }.min()
    }
}
