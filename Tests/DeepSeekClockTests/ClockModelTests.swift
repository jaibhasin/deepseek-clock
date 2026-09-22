//
//  ClockModelTests.swift
//  DeepSeekClockTests
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Tests the pure, stateless parts of `ClockModel` — currently the countdown    │
//  │ formatter. The live ticking/`UserDefaults` pieces are exercised by running   │
//  │ the app; here we only assert deterministic behavior.                         │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import XCTest
@testable import DeepSeekClock

final class ClockModelTests: XCTestCase {

    func testCountdownFormatting() {
        XCTAssertEqual(ClockModel.format(8040), "2h 14m")
        XCTAssertEqual(ClockModel.format(3600), "1h 0m")
        XCTAssertEqual(ClockModel.format(125), "2m 5s")
        XCTAssertEqual(ClockModel.format(60), "1m 0s")
        XCTAssertEqual(ClockModel.format(12), "12s")
        XCTAssertEqual(ClockModel.format(59), "59s")
    }

    /// Negative durations (clock skew, boundary races) clamp to zero rather than
    /// rendering something like "-1s".
    func testCountdownClampsNegativeDurations() {
        XCTAssertEqual(ClockModel.format(-5), "0s")
    }
}
