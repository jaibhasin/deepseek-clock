//
//  StatusView.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ The SwiftUI panel shown when the menu bar whale is clicked.                  │
//  │                                                                              │
//  │ It is presentation only: every value it shows comes from `ClockModel`, and   │
//  │ every colour/wording comes from `PricingPhase+UI.swift`. That keeps the UI   │
//  │ dumb and the pricing logic in one testable place.                            │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import SwiftUI
import AppKit

struct StatusView: View {

    // `@ObservedObject` (not `@StateObject`) because the AppDelegate owns the
    // model; this view only observes it and refreshes when it changes.
    @ObservedObject var clock: ClockModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header: the DeepSeek whale tinted green/red, plus the status text.
            HStack(spacing: 10) {
                Image(nsImage: StatusIcon.image(for: clock.phase, size: 26))
                VStack(alignment: .leading, spacing: 1) {
                    Text(clock.phase.title).font(.headline)
                    Text(clock.phase.subtitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(clock.phase.color)
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

            // A menu bar app has no window to close, so it needs an explicit way
            // to quit. Cmd-Q works while the panel is focused.
            Button("Quit DeepSeek Clock") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 250)
    }
}
