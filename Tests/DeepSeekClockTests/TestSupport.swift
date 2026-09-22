//
//  TestSupport.swift
//  DeepSeekClockTests
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Tiny helpers shared by the tests so each test reads as the behavior it is    │
//  │ checking, not as date-building boilerplate.                                  │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import Foundation

enum TestSupport {

    /// Builds a `Date` from calendar components interpreted in UTC.
    ///
    /// The pricing rules are defined in UTC, so tests describe their inputs in UTC
    /// too. Example: `utc(2026, 9, 21, 2)` is Monday 02:00 UTC.
    static func utc(_ year: Int, _ month: Int, _ day: Int,
                    _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        makeDate(in: "UTC", year, month, day, hour, minute, second)
    }

    /// Builds a `Date` from components interpreted in a specific time zone.
    ///
    /// Used to prove the calculation depends only on the absolute instant, never
    /// on the calendar/time zone used to describe it.
    static func date(in timeZoneID: String, _ year: Int, _ month: Int, _ day: Int,
                     _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        makeDate(in: timeZoneID, year, month, day, hour, minute, second)
    }

    /// Exact decimal from a string, e.g. `dec("0.006")`. String input avoids the
    /// binary rounding a `Double` literal would introduce.
    static func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }

    // MARK: - Private

    private static func makeDate(in timeZoneID: String, _ year: Int, _ month: Int,
                                 _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        let components = DateComponents(year: year, month: month, day: day,
                                        hour: hour, minute: minute, second: second)
        return calendar.date(from: components)!
    }
}
