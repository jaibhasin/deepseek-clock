//
//  ClockModel.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ The "view model" that glues the pure rules in `DeepSeekSchedule` to the UI.  │
//  │                                                                              │
//  │ It owns the published state that the menu bar renders:                       │
//  │     • phase         → is it peak or off-peak right now?                      │
//  │     • countdown     → "2h 14m" until the price changes                       │
//  │     • selectedModel → which model's rate card the user wants to see          │
//  │                                                                              │
//  │ `phase` and `countdown` are recomputed once a second by a `Timer`, so the     │
//  │ menu bar label ticks down live without any manual refresh. The selected model │
//  │ is remembered across launches via `UserDefaults`.                            │
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

    /// Which model's rate card the dropdown shows. The view binds its picker to
    /// this, so it must be publicly settable. It is persisted on every change so
    /// the user's choice survives quitting and relaunching the app.
    @Published var selectedModel: DeepSeekModel = .flash {
        didSet { UserDefaults.standard.set(selectedModel.rawValue, forKey: Self.selectedModelKey) }
    }

    /// Current rates for the selected model, already resolved to the live phase.
    /// The view reads this; it is derived, never stored.
    var currentPricing: ModelPricing {
        DeepSeekPricing.pricing(for: selectedModel, phase: phase)
    }

    /// `UserDefaults` key for remembering the selected model between launches.
    private static let selectedModelKey = "selectedModel"

    /// The rule engine. Stateless, so one instance is enough for the whole app.
    private let schedule = DeepSeekSchedule()

    /// Strong reference to the repeating timer so it isn't deallocated.
    private var timer: Timer?

    /// Called after every refresh. The AppKit shell uses this hook to repaint
    /// the menu bar icon and tooltip. Keeping it a closure means `ClockModel`
    /// still imports nothing but Foundation and stays easy to test.
    var onUpdate: (() -> Void)?

    init() {
        // Restore the model the user last picked, if any. Assigning here does not
        // trigger the `didSet` observer (property observers are skipped during
        // initialization), so we do not immediately write the value back.
        if let raw = UserDefaults.standard.string(forKey: Self.selectedModelKey),
           let saved = DeepSeekModel(rawValue: raw) {
            selectedModel = saved
        }

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
    func refresh() {
        let now = Date()
        phase = schedule.isPeak(at: now) ? .peak : .offPeak

        let remaining = schedule.nextTransition(after: now)?.timeIntervalSince(now) ?? 0
        countdown = Self.format(remaining)

        onUpdate?()
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
}
