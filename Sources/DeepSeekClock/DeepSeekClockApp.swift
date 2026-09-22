//
//  DeepSeekClockApp.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ The app entry point plus its tiny UI.                                        │
//  │                                                                              │
//  │ HOW A MENU BAR APP WORKS                                                     │
//  │ A normal macOS app owns windows and shows a Dock icon. A "menu bar app"      │
//  │ instead owns a single status item in the top-right menu bar. SwiftUI models  │
//  │ that with the `MenuBarExtra` scene (macOS 13+):                              │
//  │                                                                              │
//  │     MenuBarExtra { DROPDOWN } label: { MENU BAR TEXT }                       │
//  │                                                                              │
//  │ There is intentionally NO `WindowGroup` here, and `LSUIElement = true` in    │
//  │ Resources/Info.plist strips the Dock icon — so the app exists ONLY in the    │
//  │ menu bar.                                                                    │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import SwiftUI
import AppKit

@main
struct DeepSeekClockApp: App {

    // The single source of truth for the UI. `@StateObject` means SwiftUI
    // creates it once and keeps it alive for the app's whole lifetime. Because
    // it is an ObservableObject, every `@Published` change re-renders both the
    // menu bar label and the dropdown automatically.
    @StateObject private var clock = ClockModel()

    var body: some Scene {
        MenuBarExtra {
            // MARK: Dropdown (shown when the menu bar item is clicked)
            StatusView(clock: clock)
        } label: {
            // MARK: Menu bar label (always visible)
            // e.g. "Off-peak 2h 14m". `.monospacedDigit()` keeps the digits
            // from jittering sideways as the countdown ticks.
            Text(clock.menuBarTitle)
                .monospacedDigit()
        }
        // `.window` gives the dropdown a real SwiftUI view (padding, dividers,
        // buttons) instead of a plain system menu.
        .menuBarExtraStyle(.window)
    }
}

/// Contents of the dropdown panel.
struct StatusView: View {

    // `@ObservedObject` (not `@StateObject`) because the App owns the model;
    // this view merely observes it and refreshes when it changes.
    @ObservedObject var clock: ClockModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header: phase icon + a plain-English status line.
            HStack(spacing: 8) {
                Image(systemName: clock.phase.symbol)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(clock.phase.title).font(.headline)
                    Text(clock.phase.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // The point of the app: how long until the price changes.
            HStack {
                Text(clock.phase.changeLabel)
                Spacer()
                Text(clock.countdown)
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }

            Divider()

            // A menu bar app has no window to close, so it needs an explicit
            // way to quit. Cmd-Q works while the panel is focused.
            Button("Quit DeepSeek Clock") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 250)
    }
}
