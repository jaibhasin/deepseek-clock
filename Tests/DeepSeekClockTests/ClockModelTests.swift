//
//  ClockModelTests.swift
//  DeepSeekClockTests
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Tests the pure, stateless parts of `ClockModel` — the countdown formatter    │
//  │ and the adaptive refresh cadence. The live ticking/`UserDefaults` pieces are │
//  │ exercised by running the app; here we only assert deterministic behavior.    │
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

    /// The transition time is rendered in whichever zone is requested, so the same
    /// instant reads differently for different display zones.
    func testTransitionFormattingUsesRequestedTimeZone() {
        let transition = TestSupport.utc(2026, 9, 21, 4, 0)
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

        let kolkataText = ClockModel.formatTransition(transition, in: kolkata)
        let losAngelesText = ClockModel.formatTransition(transition, in: losAngeles)

        XCTAssertFalse(kolkataText.isEmpty)
        XCTAssertNotEqual(kolkataText, losAngelesText)
    }

    // MARK: - Off-peak notification

    /// The alert belongs to exactly one edge: peak → off-peak.
    func testNotifiesOnlyOnPeakToOffPeakCrossing() {
        XCTAssertTrue(ClockModel.shouldNotifyOffPeak(from: .peak, to: .offPeak))

        // Repeats, reverse crossings and no-ops must all stay silent.
        XCTAssertFalse(ClockModel.shouldNotifyOffPeak(from: .offPeak, to: .offPeak))
        XCTAssertFalse(ClockModel.shouldNotifyOffPeak(from: .peak, to: .peak))
        XCTAssertFalse(ClockModel.shouldNotifyOffPeak(from: .offPeak, to: .peak))
    }

    /// The first tick has no previous phase; launching while already off-peak must
    /// not fire a notification.
    func testDoesNotNotifyOnFirstTick() {
        XCTAssertFalse(ClockModel.shouldNotifyOffPeak(from: nil, to: .offPeak))
    }

    /// A previously disabled preference must not suppress automatic alerts.
    func testRequestsAuthorizationEvenWhenLegacyPreferenceIsDisabled() {
        let defaults = UserDefaults.standard
        let key = "notifyOnOffPeak"
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(false, forKey: key)
        let notifications = NotificationSpy()
        let model = ClockModel(notifications: notifications)
        defer { model.pauseTicking() }

        XCTAssertEqual(notifications.authorizationRequests, 1)
        XCTAssertEqual(notifications.offPeakAlerts, 0)
        model.refresh()
        XCTAssertEqual(notifications.authorizationRequests, 1)
    }

    // MARK: - Adaptive refresh cadence

    /// With the panel open the countdown is read live, so under an hour remaining
    /// we tick every second.
    func testOpenPanelTicksEverySecondUnderAnHour() {
        let now = TestSupport.utc(2026, 9, 21, 12, 0, 0)
        XCTAssertEqual(ClockModel.refreshDelay(remaining: 100, panelOpen: true, now: now), 1)
    }

    /// Over an hour the countdown only shows whole minutes, so even an open panel
    /// drops to the cheaper minute cadence.
    func testOpenPanelDoesNotTickEverySecondOverAnHour() {
        let now = TestSupport.utc(2026, 9, 21, 12, 0, 0)
        XCTAssertGreaterThan(ClockModel.refreshDelay(remaining: 7200, panelOpen: true, now: now), 1)
    }

    /// A closed panel stays on the minute cadence no matter how little time is
    /// left — nothing on screen changes faster than once a minute.
    func testClosedPanelNeverTicksEverySecond() {
        let now = TestSupport.utc(2026, 9, 21, 12, 0, 30)
        XCTAssertGreaterThan(ClockModel.refreshDelay(remaining: 10, panelOpen: false, now: now), 1)
    }

    /// The timer must never sleep past the phase transition, or the icon colour and
    /// notification would arrive late.
    func testDelayNeverOutlivesTheTransition() {
        let now = TestSupport.utc(2026, 9, 21, 12, 0, 30)
        XCTAssertLessThanOrEqual(ClockModel.refreshDelay(remaining: 5, panelOpen: false, now: now), 5)
    }

    /// A transition in the past (clock skew) still yields a small positive delay so
    /// the app can never busy-loop.
    func testDelayHasSaneMinimum() {
        let now = TestSupport.utc(2026, 9, 21, 12, 0, 0)
        let delay = ClockModel.refreshDelay(remaining: -30, panelOpen: true, now: now)
        XCTAssertGreaterThanOrEqual(delay, 0.5)
    }

    /// `secondsUntilNextMinute` aims just past the boundary, never before it.
    func testSecondsUntilNextMinuteLandsJustAfterBoundary() {
        XCTAssertEqual(ClockModel.secondsUntilNextMinute(from: TestSupport.utc(2026, 9, 21, 12, 0, 0)),
                       60.05, accuracy: 0.001)
        XCTAssertEqual(ClockModel.secondsUntilNextMinute(from: TestSupport.utc(2026, 9, 21, 12, 0, 30)),
                       30.05, accuracy: 0.001)
    }
}

private final class NotificationSpy: NotificationService {
    private(set) var authorizationRequests = 0
    private(set) var offPeakAlerts = 0

    func requestAuthorization() {
        authorizationRequests += 1
    }

    func notifyOffPeakStarted() {
        offPeakAlerts += 1
    }
}
