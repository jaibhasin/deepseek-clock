//
//  DeepSeekClockApp.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ App entry point. Owns the macOS "status item" (the thing in the menu bar)    │
//  │ and the popover that appears when you click it.                              │
//  │                                                                              │
//  │ WHY APPKIT INSTEAD OF SWIFTUI'S `MenuBarExtra`?                              │
//  │ A hand-rolled `NSStatusItem` gives us direct control over the button's       │
//  │ image and a live, per-second tooltip, which is all this little shell needs.  │
//  │ The whale glyph (see `StatusIcon.swift`) is redrawn whenever the phase or    │
//  │ the light/dark appearance changes.                                           │
//  │                                                                              │
//  │ The dropdown itself is still 100% SwiftUI (`StatusView`) hosted inside an    │
//  │ `NSPopover` — we only drop to AppKit for the status item shell.              │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    /// Single source of truth for pricing state, shared by the icon and popover.
    private let clock = ClockModel()

    /// The menu bar item itself.
    private var statusItem: NSStatusItem!

    /// The panel shown on click, hosting the SwiftUI `StatusView`.
    private let popover = NSPopover()

    /// Last phase we drew, so we only rebuild the icon when the colour changes
    /// (redrawing the image every tick is wasteful).
    private var lastPaintedPhase: PricingPhase?

    /// The appearance (light/dark) the icon was last drawn for. The whale body
    /// follows the menu bar, so a theme switch also needs a redraw.
    private var lastPaintedAppearance: NSAppearance.Name?

    /// Watches for light/dark switches so the whale body can be redrawn to match.
    private var appearanceObservation: NSKeyValueObservation?

    /// Last tooltip we set, so an unchanged string is not reassigned on every tick.
    private var lastPaintedTooltip: String?

    // MARK: - Entry point

    /// We are an accessory app: no Dock icon and no app switcher entry, which is
    /// exactly what a menu bar utility should be. (LSUIElement in Info.plist does
    /// the same thing for the packaged .app; setting it here also covers `swift run`.)
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPopover()
        observeSystemEvents()

        // Repaint whenever the model refreshes.
        clock.onUpdate = { [weak self] in self?.paint() }
        paint()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appearanceObservation?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.image = StatusIcon.image(for: clock.phase)
        statusItem.button?.imagePosition = .imageOnly

        // Re-draw the whale when the system flips between light and dark mode.
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.paint()
        }
    }

    private func setUpPopover() {
        // `.transient` closes the popover automatically when you click elsewhere.
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: StatusView(clock: clock))
    }

    /// Subscribes to the system events that can invalidate our cached state.
    ///
    /// A menu bar app can run for days, so it must not trust its timer to have
    /// fired on schedule. Timers are suspended while the Mac sleeps, and the clock
    /// or time zone can change underneath us, so we recompute from scratch on:
    ///   • `didWake`  — the machine just woke; catch up and re-arm the timer;
    ///   • `willSleep`— stop ticking while asleep (no point waking the CPU);
    ///   • clock/time-zone changes — the displayed local time may have moved.
    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemStateChanged),
                              name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemWillSleep),
                              name: NSWorkspace.willSleepNotification, object: nil)

        let defaultCenter = NotificationCenter.default
        defaultCenter.addObserver(self, selector: #selector(systemStateChanged),
                                  name: .NSSystemClockDidChange, object: nil)
        defaultCenter.addObserver(self, selector: #selector(systemStateChanged),
                                  name: .NSSystemTimeZoneDidChange, object: nil)
    }

    /// Recompute phase/countdown immediately after the system changed underneath us.
    @objc private func systemStateChanged() {
        clock.refresh()
    }

    /// Sleep suspends timers anyway; dropping ours makes that explicit and avoids a
    /// burst of catch-up fires the instant the Mac wakes.
    @objc private func systemWillSleep() {
        clock.pauseTicking()
    }

    // MARK: - NSPopoverDelegate

    /// The panel shows a live countdown, so switch the model to its fast cadence
    /// while it is visible, and back to the cheap cadence when it closes.
    func popoverDidShow(_ notification: Notification) {
        clock.setPanelOpen(true)
    }

    func popoverDidClose(_ notification: Notification) {
        clock.setPanelOpen(false)
    }

    // MARK: - Rendering

    /// Pushes the current phase/countdown into the status item.
    ///
    /// The icon carries the phase colour in its spout, so it is rebuilt only when
    /// the phase or the light/dark appearance actually changes. The tooltip is
    /// likewise only rewritten when its text changes.
    private func paint() {
        guard let button = statusItem.button else { return }

        let appearance = NSApp.effectiveAppearance.name
        if clock.phase != lastPaintedPhase || appearance != lastPaintedAppearance {
            button.image = StatusIcon.image(for: clock.phase)
            lastPaintedPhase = clock.phase
            lastPaintedAppearance = appearance
        }

        // Only touch the tooltip/accessibility text when it actually changed. Each
        // assignment is cheap, but skipping identical ones keeps idle work at zero.
        let tooltip = "\(clock.phase.title) · \(clock.phase.changeLabel) \(clock.countdown)"
        guard tooltip != lastPaintedTooltip else { return }

        button.toolTip = tooltip
        button.setAccessibilityLabel("DeepSeek pricing: \(clock.phase.title), \(clock.countdown) left")
        lastPaintedTooltip = tooltip
    }

    // MARK: - Interaction

    /// Clicking the whale toggles the dropdown panel.
    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        // Bring the app forward so the popover can take keyboard focus
        // (needed for the Cmd-Q shortcut inside `StatusView`).
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
