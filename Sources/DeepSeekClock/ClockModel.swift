//
//  ClockModel.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ The "view model" that glues the pure rules in `DeepSeekSchedule` to the UI.  │
//  │                                                                              │
//  │ It owns the published state that the menu bar renders:                       │
//  │     • phase          → is it peak or off-peak right now?                     │
//  │     • countdown      → "2h 14m" until the price changes                      │
//  │     • selectedModel  → which model's rate card the user wants to see         │
//  │     • notifyOnOffPeak → should we alert when cheap pricing begins?           │
//  │                                                                              │
//  │ `phase` and `countdown` are recomputed by a *self-rescheduling* timer that    │
//  │ only wakes the CPU when the on-screen information could actually change:      │
//  │     • once a minute while the panel is closed (the countdown only changes by  │
//  │       the minute in that state), and                                         │
//  │     • once a second only while the panel is open and under an hour remains.  │
//  │ It also refreshes immediately at the next phase transition, and on system     │
//  │ events such as wake-from-sleep or a time-zone change (see `AppDelegate`).      │
//  │ The selected model and the notification preference are remembered across      │
//  │ launches via `UserDefaults`.                                                  │
//  │                                                                              │
//  │ SIDE EFFECTS ARE INJECTED                                                     │
//  │ Sending a notification is a side effect the model must not hard-code, so it  │
//  │ is handed a `NotificationService` at init. Tests can pass a spy instead.     │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
//  WHAT IS `ObservableObject`?
//  ---------------------------
//  `ObservableObject` is SwiftUI's older-but-ubiquitous observation protocol.
//  Any property marked `@Published` automatically tells SwiftUI "this changed,
//  redraw whatever depends on me". The App/view holds this object and therefore
//  re-renders the instant `phase` or `countdown` is updated.
//
import Foundation

/// Drives the menu bar UI with a once-per-second refresh loop.
final class ClockModel: ObservableObject {

    /// Current pricing phase. `private(set)` = the view can read it but only
    /// this class may change it, keeping state changes in one place.
    @Published private(set) var phase: PricingPhase = .offPeak

    /// Human-readable time until the next phase change, e.g. "2h 14m".
    @Published private(set) var countdown: String = "--"

    /// The absolute instant of the next phase change. The view renders this in
    /// the Mac's current time zone (see `formattedTransition`), so the user sees
    /// "when it ends" on their own clock, not in UTC.
    @Published private(set) var transitionDate: Date?

    /// The next transition as a local wall-clock time, e.g. "4:00 AM", or `nil`
    /// while we have not computed one yet.
    var formattedTransition: String? {
        transitionDate.map(Self.formatTransition)
    }

    /// Which model's rate card the dropdown shows. The view binds its picker to
    /// this, so it must be publicly settable. It is persisted on every change so
    /// the user's choice survives quitting and relaunching the app.
    @Published var selectedModel: DeepSeekModel = .flash {
        didSet { UserDefaults.standard.set(selectedModel.rawValue, forKey: Self.selectedModelKey) }
    }

    /// Whether the user wants a system notification when peak turns into off-peak.
    /// The view binds a toggle to this. Persisted on change; switching it on also
    /// asks macOS for notification permission so the alert can actually appear.
    @Published var notifyOnOffPeak: Bool = false {
        didSet {
            UserDefaults.standard.set(notifyOnOffPeak, forKey: Self.notifyOnOffPeakKey)
            if notifyOnOffPeak { notifications.requestAuthorization() }
        }
    }

    /// Current rates for the selected model, already resolved to the live phase.
    /// The view reads this; it is derived, never stored.
    var currentPricing: ModelPricing {
        DeepSeekPricing.pricing(for: selectedModel, phase: phase)
    }

    /// `UserDefaults` keys for the two remembered preferences.
    private static let selectedModelKey = "selectedModel"
    private static let notifyOnOffPeakKey = "notifyOnOffPeak"

    /// The rule engine. Stateless, so one instance is enough for the whole app.
    private let schedule = DeepSeekSchedule()

    /// Delivers the off-peak alert. Injected so tests can swap in a spy.
    private let notifications: NotificationService

    /// The phase we saw on the previous tick, or `nil` before the first tick.
    /// Comparing it against the freshly computed phase is what lets us fire the
    /// notification exactly once per peak → off-peak crossing, and never on launch.
    private var previousPhase: PricingPhase?

    /// Strong reference to the single pending timer so it isn't deallocated.
    /// We use a *one-shot* timer that re-arms itself in `scheduleNextRefresh()`,
    /// instead of a fixed repeating timer, so the wake-up interval can adapt to
    /// what is actually visible.
    private var timer: Timer?

    /// `true` while the dropdown panel is open. The panel shows a live countdown,
    /// so we tick every second in that state; when it is closed there is nothing
    /// on screen that changes faster than once a minute.
    private var isPanelOpen = false

    /// Called after every refresh. The AppKit shell uses this hook to repaint
    /// the menu bar icon and tooltip. Keeping it a closure means `ClockModel`
    /// still imports nothing but Foundation and stays easy to test.
    var onUpdate: (() -> Void)?

    init(notifications: NotificationService = UserNotificationService()) {
        self.notifications = notifications

        // Restore the model the user last picked, if any. Assigning here does not
        // trigger the `didSet` observer (property observers are skipped during
        // initialization), so we do not immediately write the value back.
        if let raw = UserDefaults.standard.string(forKey: Self.selectedModelKey),
           let saved = DeepSeekModel(rawValue: raw) {
            selectedModel = saved
        }

        // Restore the notification preference. `bool(forKey:)` returns `false`
        // when the key has never been set, which is the default we want.
        notifyOnOffPeak = UserDefaults.standard.bool(forKey: Self.notifyOnOffPeakKey)

        // Show correct values immediately; `refresh()` also arms the timer.
        refresh()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Timing

    /// Recomputes `phase` and `countdown` from the current time, then arms the
    /// next wake-up.
    ///
    /// Also watches for the one crossing worth announcing: peak → off-peak. The
    /// notification fires only when both the previous tick was peak and this tick
    /// is off-peak, which makes it impossible to spam (and means launching the app
    /// while already off-peak stays silent).
    ///
    /// Call this directly after a system event (wake, clock/time-zone change) so
    /// stale state is corrected at once instead of waiting for the next tick.
    func refresh() {
        let now = Date()
        let newPhase: PricingPhase = schedule.isPeak(at: now) ? .peak : .offPeak

        if Self.shouldNotifyOffPeak(from: previousPhase, to: newPhase, enabled: notifyOnOffPeak) {
            notifications.notifyOffPeakStarted()
        }

        phase = newPhase
        previousPhase = newPhase

        let next = schedule.nextTransition(after: now)
        transitionDate = next
        let remaining = next?.timeIntervalSince(now) ?? 0
        countdown = Self.format(remaining)

        onUpdate?()
        scheduleNextRefresh()
    }

    /// Tells the model whether the dropdown panel is currently on screen.
    ///
    /// Opening it forces an immediate refresh (so the panel is never stale) and
    /// switches to second-by-second ticking; closing it drops back to the cheaper
    /// once-a-minute cadence.
    func setPanelOpen(_ open: Bool) {
        guard open != isPanelOpen else { return }
        isPanelOpen = open
        refresh()
    }

    /// Stops the timer entirely — used just before the Mac sleeps, when it could
    /// not fire anyway. The wake observer calls `refresh()`, which re-arms it.
    func pauseTicking() {
        timer?.invalidate()
        timer = nil
    }

    /// Arms a single timer for the next moment the displayed information can
    /// change, replacing any timer already pending.
    ///
    /// The cadence is deliberately conservative:
    ///   • panel open & < 1h left → 1s (a live countdown the user is reading);
    ///   • otherwise              → the next minute boundary (the countdown is
    ///                              only shown to the minute in this state).
    /// The delay is capped by the time to the phase transition so the icon colour
    /// and the off-peak notification never arrive late.
    private func scheduleNextRefresh() {
        timer?.invalidate()

        let now = Date()
        let remaining = transitionDate?.timeIntervalSince(now) ?? 0
        let delay = Self.refreshDelay(remaining: remaining, panelOpen: isPanelOpen, now: now)

        // `[weak self]` avoids a retain cycle (timer → closure → self → timer).
        // `.common` keeps the tick alive while menus/popovers are tracking events.
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// The pure timing rule behind `scheduleNextRefresh()`.
    ///
    /// Extracted as a static function so the cadence can be asserted in unit tests
    /// without waiting on a real clock or run loop.
    static func refreshDelay(remaining: TimeInterval, panelOpen: Bool, now: Date) -> TimeInterval {
        // The countdown string changes every second only while it is under an hour
        // (above that it shows whole minutes); and only the open panel shows it.
        let wantsSecondTick = panelOpen && remaining < 3600

        let proposed = wantsSecondTick ? 1 : secondsUntilNextMinute(from: now)

        // Never sleep past the transition, and always wait a sane minimum so we can
        // never busy-loop if the clock jumps backwards.
        return max(0.5, min(proposed, max(remaining, 0.5)))
    }

    /// Seconds from `date` until the next whole minute, plus a small margin so the
    /// timer lands just *after* the boundary rather than a hair before it.
    static func secondsUntilNextMinute(from date: Date) -> TimeInterval {
        // `.autoupdatingCurrent` follows the Mac's time zone, and the "second"
        // component is the same in every zone anyway (offsets are whole minutes).
        let second = Calendar.autoupdatingCurrent.component(.second, from: date)
        return TimeInterval(60 - second) + 0.05
    }

    /// The pure rule behind the notification: alert only when the phase just flipped
    /// from peak to off-peak *and* the user asked for it.
    ///
    /// Extracted as a static function so the decision can be unit-tested without a
    /// timer, a real clock or a real notification center.
    static func shouldNotifyOffPeak(
        from previous: PricingPhase?,
        to current: PricingPhase,
        enabled: Bool
    ) -> Bool {
        enabled && previous == .peak && current == .offPeak
    }

    // MARK: - Formatting

    /// Turns a duration into a short string that fits the menu bar.
    ///
    /// Examples: 8040s → "2h 14m", 125s → "2m 5s", 12s → "12s".
    /// Hours suppress seconds (they would never be seen at menu-bar size);
    /// once we're under a minute we show seconds so the countdown stays lively.
    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }

    /// Formats an absolute transition instant as a local time, e.g. "4:00 AM".
    ///
    /// `timeZone = .autoupdatingCurrent` is the key line: it follows whatever time
    /// zone the Mac is set to *right now*, without us ever hardcoding one. Built
    /// once and reused because `DateFormatter` is comparatively expensive.
    private static let transitionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static func formatTransition(_ date: Date) -> String {
        transitionFormatter.string(from: date)
    }
}
