//
//  DeepSeekScheduleTests.swift
//  DeepSeekClockTests
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Verifies the pure peak/off-peak rule engine against DeepSeek's published      │
//  │ schedule:                                                                    │
//  │     • PEAK  = 01:00–04:00 and 06:00–10:00 UTC, Monday–Friday                 │
//  │     • OFF   = everything else, including the whole weekend                   │
//  │                                                                              │
//  │ Reference dates (2026):  Sep 21 = Mon, 25 = Fri, 26 = Sat, 27 = Sun,         │
//  │                          28 = Mon.                                          │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import XCTest
@testable import DeepSeekClock

final class DeepSeekScheduleTests: XCTestCase {

    private let schedule = DeepSeekSchedule()

    // MARK: - isPeak: window boundaries on a weekday

    /// The edges matter most: a window is `[start, end)` — the start is peak, the
    /// end is already off-peak.
    func testPeakWindowBoundariesOnMonday() {
        XCTAssertFalse(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, 0, 59)))
        XCTAssertTrue(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, 1, 0)))
        XCTAssertTrue(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, 3, 59)))
        XCTAssertFalse(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, 4, 0)))
        XCTAssertFalse(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, 5, 59)))
        XCTAssertTrue(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, 6, 0)))
        XCTAssertTrue(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, 9, 59)))
        XCTAssertFalse(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, 10, 0)))
    }

    /// Both windows are peak on every weekday, Monday through Friday.
    func testEveryWeekdayIsPeakInsideBothWindows() {
        for day in 21...25 { // Mon–Fri
            XCTAssertTrue(schedule.isPeak(at: TestSupport.utc(2026, 9, day, 2, 0)),
                          "day \(day) at 02:00 UTC should be peak")
            XCTAssertTrue(schedule.isPeak(at: TestSupport.utc(2026, 9, day, 7, 0)),
                          "day \(day) at 07:00 UTC should be peak")
        }
    }

    /// The whole weekend is off-peak, even during the weekday peak hours.
    func testWeekendsAreAlwaysOffPeak() {
        for day in [26, 27] { // Sat, Sun
            for hour in [0, 2, 7, 12, 23] {
                XCTAssertFalse(schedule.isPeak(at: TestSupport.utc(2026, 9, day, hour, 0)),
                               "day \(day) at \(hour):00 UTC should be off-peak")
            }
        }
    }

    /// Weekday hours outside the two windows are off-peak.
    func testNonPeakWeekdayHoursAreOffPeak() {
        for hour in [0, 4, 5, 10, 11, 12, 18, 23] {
            XCTAssertFalse(schedule.isPeak(at: TestSupport.utc(2026, 9, 21, hour, 0)),
                           "Monday \(hour):00 UTC should be off-peak")
        }
    }

    // MARK: - nextTransition

    /// From inside the first window, the next flip is that window's end (04:00).
    func testTransitionWithinFirstWindow() {
        XCTAssertEqual(schedule.nextTransition(after: TestSupport.utc(2026, 9, 21, 2, 0)),
                       TestSupport.utc(2026, 9, 21, 4, 0))
    }

    /// Between the windows, the next flip is the start of the second (06:00).
    func testTransitionBetweenWindows() {
        XCTAssertEqual(schedule.nextTransition(after: TestSupport.utc(2026, 9, 21, 4, 30)),
                       TestSupport.utc(2026, 9, 21, 6, 0))
    }

    /// After the second window, the next flip is the next weekday's first window.
    func testTransitionAfterLastWindowJumpsToNextDay() {
        XCTAssertEqual(schedule.nextTransition(after: TestSupport.utc(2026, 9, 21, 10, 30)),
                       TestSupport.utc(2026, 9, 22, 1, 0))
    }

    /// After Friday's last window, the next flip is Monday 01:00 — the weekend in
    /// between has no transitions at all.
    func testTransitionFromFridayEveningJumpsToMonday() {
        XCTAssertEqual(schedule.nextTransition(after: TestSupport.utc(2026, 9, 25, 10, 30)),
                       TestSupport.utc(2026, 9, 28, 1, 0))
    }

    /// From anywhere on the weekend, the next flip is Monday 01:00.
    func testTransitionAcrossWeekend() {
        XCTAssertEqual(schedule.nextTransition(after: TestSupport.utc(2026, 9, 26, 12, 0)),
                       TestSupport.utc(2026, 9, 28, 1, 0))
        XCTAssertEqual(schedule.nextTransition(after: TestSupport.utc(2026, 9, 27, 23, 0)),
                       TestSupport.utc(2026, 9, 28, 1, 0))
    }

    /// The boundary lookup is strictly "after": standing exactly on a boundary
    /// returns the *next* one, never the current instant.
    func testTransitionIsStrictlyAfterTheGivenDate() {
        XCTAssertEqual(schedule.nextTransition(after: TestSupport.utc(2026, 9, 21, 1, 0)),
                       TestSupport.utc(2026, 9, 21, 4, 0))
    }

    /// A transition always exists, no matter which instant we ask from.
    func testTransitionAlwaysFound() {
        for hour in stride(from: 0, to: 24, by: 3) {
            XCTAssertNotNil(schedule.nextTransition(after: TestSupport.utc(2026, 9, 21, hour, 0)))
        }
    }

    // MARK: - Time zone independence

    /// The engine is defined in UTC, so the same absolute instant must produce the
    /// same answer no matter which time zone's calendar was used to build it.
    func testCalculationIsIndependentOfDescribingTimeZone() {
        // 2026-09-21 11:00 in Tokyo (UTC+9) is the same instant as 02:00 UTC.
        let peakInstant = TestSupport.date(in: "Asia/Tokyo", 2026, 9, 21, 11, 0)
        XCTAssertEqual(peakInstant, TestSupport.utc(2026, 9, 21, 2, 0))
        XCTAssertTrue(schedule.isPeak(at: peakInstant))

        // 2026-09-21 14:00 in Tokyo == 05:00 UTC, which is off-peak.
        let offPeakInstant = TestSupport.date(in: "Asia/Tokyo", 2026, 9, 21, 14, 0)
        XCTAssertEqual(offPeakInstant, TestSupport.utc(2026, 9, 21, 5, 0))
        XCTAssertFalse(schedule.isPeak(at: offPeakInstant))
    }
}
