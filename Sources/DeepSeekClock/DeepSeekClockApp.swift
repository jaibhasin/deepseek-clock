//
//  DeepSeekClockApp.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ App entry point. Owns the macOS "status item" (the thing in the menu bar)    │
//  │ and the panel that appears when you click it.                              │
//  │                                                                              │
//  │ WHY APPKIT INSTEAD OF SWIFTUI'S `MenuBarExtra`?                              │
//  │ A hand-rolled `NSStatusItem` gives us direct control over the button's       │
//  │ image and a live, per-second tooltip, which is all this little shell needs.  │
//  │ The whale uses native template rendering for contrast, with a coloured      │
//  │ spout overlaid to show the current pricing phase.                            │
//  │                                                                              │
//  │ The dropdown itself is still 100% SwiftUI (`StatusView`) hosted inside an    │
//  │ `NSPanel` - AppKit handles positioning and keyboard focus.              │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    /// Single source of truth for pricing state, shared by the icon and panel.
    private let clock = ClockModel()

    /// The menu bar item itself.
    private var statusItem: NSStatusItem!
    private let spoutView = StatusSpoutView()

    /// The panel shown on click, hosting the SwiftUI `StatusView`.
    private let panel = StatusPanel()
    private lazy var panelContent = NSHostingController(rootView: StatusView(clock: clock))
    private var outsideClickMonitor: Any?
    private var localEventMonitor: Any?

    /// Last phase we drew, so we only update the coloured spout when it changes.
    private var lastPaintedPhase: PricingPhase?

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
        setUpPanel()
        observeSystemEvents()

        // Repaint whenever the model refreshes.
        clock.onUpdate = { [weak self] in self?.paint() }
        paint()
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeEventMonitors()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        button.image = StatusIcon.menuBarImage()
        button.imagePosition = .imageOnly

        spoutView.image = StatusIcon.spoutImage(for: clock.phase)
        spoutView.imageScaling = .scaleNone
        spoutView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(spoutView)
        NSLayoutConstraint.activate([
            spoutView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            spoutView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            spoutView.widthAnchor.constraint(equalToConstant: 18),
            spoutView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func setUpPanel() {
        panel.delegate = self
        panel.contentViewController = panelContent
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

    // MARK: - Panel dismissal

    func windowDidResignKey(_ notification: Notification) {
        // Let the status button's action handle a second click without reopening.
        if let button = statusItem.button, let window = button.window {
            let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
            if frame.contains(NSEvent.mouseLocation) { return }
        }
        closePanel()
    }

    private func closePanel() {
        removeEventMonitors()
        statusItem.button?.highlight(false)
        clock.setPanelOpen(false)
        if panel.isVisible { panel.orderOut(nil) }
    }

    private func removeEventMonitors() {
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localEventMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
        localEventMonitor = nil
    }

    private func monitorPanelDismissal() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in self?.closePanel() }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.closePanel()
                    return nil
                }
            } else if event.window !== self.panel,
                      event.window !== self.statusItem.button?.window {
                self.closePanel()
            }
            return event
        }
    }

    // MARK: - Rendering

    /// Pushes the current phase/countdown into the status item.
    ///
    /// The spout is updated only when the phase changes. The tooltip is likewise
    /// only rewritten when its text changes.
    private func paint() {
        guard let button = statusItem.button else { return }

        // The panel's content can change height (inline settings, a currency
        // status line appearing). SwiftUI lays out asynchronously, so re-measure on
        // the next run-loop pass; `refitPanelIfVisible` only resizes when it needs to.
        if panel.isVisible {
            DispatchQueue.main.async { [weak self] in self?.refitPanelIfVisible() }
        }

        if clock.phase != lastPaintedPhase {
            spoutView.image = StatusIcon.spoutImage(for: clock.phase)
            lastPaintedPhase = clock.phase
        }

        // Only touch the tooltip/accessibility text when it actually changed. Each
        // assignment is cheap, but skipping identical ones keeps idle work at zero.
        let tooltip = "\(clock.phase.title) · \(clock.phase.changeLabel) \(clock.countdown)"
        guard tooltip != lastPaintedTooltip else { return }

        button.toolTip = tooltip
        button.setAccessibilityLabel("DeepSeek pricing: \(clock.phase.title), \(clock.countdown) left")
        lastPaintedTooltip = tooltip
    }

    /// Resizes the visible panel to fit its current content, keeping it anchored
    /// below the status item. Used when the inline settings screen changes height.
    private func refitPanelIfVisible() {
        guard panel.isVisible,
              let button = statusItem.button,
              let window = button.window else { return }

        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(
            NSPoint(x: buttonFrame.midX, y: buttonFrame.midY)
        ) }) ?? window.screen ?? NSScreen.main else { return }

        let size = panelContent.sizeThatFits(in: NSSize(width: 292, height: screen.visibleFrame.height))
        let frame = PanelPlacement.frame(size: size,
                                         below: buttonFrame, screen: screen.visibleFrame)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
    }

    // MARK: - Interaction

    /// Clicking the whale toggles the dropdown panel.
    @objc private func togglePanel() {
        guard let button = statusItem.button, let window = button.window else { return }

        if panel.isVisible {
            closePanel()
            return
        }

        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(
            NSPoint(x: buttonFrame.midX, y: buttonFrame.midY)
        ) }) ?? window.screen ?? NSScreen.main else { return }

        clock.refresh()
        // Always open on the main screen, not wherever the user left settings.
        clock.isShowingSettings = false
        // Measure SwiftUI explicitly; fittingSize on an unshown hosting view can be zero.
        let size = panelContent.sizeThatFits(in: NSSize(width: 292, height: screen.visibleFrame.height))
        let frame = PanelPlacement.frame(size: size,
                                         below: buttonFrame, screen: screen.visibleFrame)
        // Set the final frame before showing, with no popover arrow or repositioning.
        panel.setFrame(frame, display: false)
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        clock.setPanelOpen(true)
        monitorPanelDismissal()
    }
}

/// Let clicks on the coloured spout reach the status button underneath it.
private final class StatusSpoutView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
