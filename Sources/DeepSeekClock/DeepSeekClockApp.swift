//
//  DeepSeekClockApp.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ App entry point. Owns the macOS "status item" (the thing in the menu bar)    │
//  │ and the popover that appears when you click it.                              │
//  │                                                                              │
//  │ WHY APPKIT INSTEAD OF SWIFTUI'S `MenuBarExtra`?                              │
//  │ `MenuBarExtra` draws its label as a *template* image — the system flattens   │
//  │ it to plain monochrome, which would throw away our green/red signal.        │
//  │ A hand-rolled `NSStatusItem` lets us set a non-template, pre-tinted image    │
//  │ (see `StatusIcon.swift`), so the colour reliably survives.                   │
//  │                                                                              │
//  │ The dropdown itself is still 100% SwiftUI (`StatusView`) hosted inside an    │
//  │ `NSPopover` — we only drop to AppKit for the status item shell.              │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Single source of truth for pricing state, shared by the icon and popover.
    private let clock = ClockModel()

    /// The menu bar item itself.
    private var statusItem: NSStatusItem!

    /// The panel shown on click, hosting the SwiftUI `StatusView`.
    private let popover = NSPopover()

    /// Last phase we drew, so we only rebuild the icon when the colour changes
    /// (the timer ticks every second; redrawing the image every tick is wasteful).
    private var lastPaintedPhase: PricingPhase?

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

        // Repaint whenever the model refreshes (once a second).
        clock.onUpdate = { [weak self] in self?.paint() }
        paint()
    }

    // MARK: - Setup

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.imagePosition = .imageOnly
    }

    private func setUpPopover() {
        // `.transient` closes the popover automatically when you click elsewhere.
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatusView(clock: clock))
    }

    // MARK: - Rendering

    /// Pushes the current phase/countdown into the status item. The icon is only
    /// rebuilt when the phase (colour) changes; the tooltip updates every tick.
    private func paint() {
        guard let button = statusItem.button else { return }

        if clock.phase != lastPaintedPhase {
            button.image = StatusIcon.image(for: clock.phase)
            lastPaintedPhase = clock.phase
        }

        button.toolTip = "\(clock.phase.title) · \(clock.phase.changeLabel) \(clock.countdown)"
        button.setAccessibilityLabel("DeepSeek pricing: \(clock.phase.title), \(clock.countdown) left")
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
