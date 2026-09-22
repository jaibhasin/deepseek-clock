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
//  │ `phase` and `countdown` are recomputed once a second by a `Timer`, so the     │
//  │ menu bar label ticks down live without any manual refresh. The selected model │
//  │ and the notification preference are remembered across launches via           │
//  │ `UserDefaults`.                                                              │
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

    /// Strong reference to the repeating timer so it isn't deallocated.
    private var timer: Timer?

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

        // Show correct values immediately, then keep them fresh every second.
        refresh()
        startTicking()
    }

    // MARK: - Timing

    /// Starts a 1-second repeating timer on the main run loop.
    ///
    /// `[weak self]` avoids a retain cycle (timer → closure → self → timer).
    /// `.common` run-loop mode keeps it firing while menus/popovers are open.
    private func startTicking() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Recomputes `phase` and `countdown` from the current time.
    ///
    /// Also watches for the one crossing worth announcing: peak → off-peak. The
    /// notification fires only when both the previous tick was peak and this tick
    /// is off-peak, which makes it impossible to spam (and means launching the app
    /// while already off-peak stays silent).
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
