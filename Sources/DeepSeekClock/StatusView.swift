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

            // Model toggle. DeepSeek prices two models, and showing both at once
            // would crowd this small panel, so the user picks one to inspect.
            Picker("Model", selection: $clock.selectedModel) {
                ForEach(DeepSeekModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Current rate card for the selected model, already resolved to the
            // live phase (peak or off-peak) by `ClockModel.currentPricing`.
            VStack(alignment: .leading, spacing: 4) {
                Text("USD per 1M tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                priceRow("Input · cache hit", clock.currentPricing.inputCacheHit)
                priceRow("Input · cache miss", clock.currentPricing.inputCacheMiss)
                priceRow("Output", clock.currentPricing.output)
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

    /// One "label .................. $0.30" line of the rate card.
    ///
    /// The value is rendered with `USDPriceFormatter` so every price uses the
    /// same currency style, and `monospacedDigit()` keeps the decimal points
    /// aligned as the numbers change when the phase flips.
    private func priceRow(_ label: String, _ value: Decimal) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(USDPriceFormatter.string(value))
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .font(.callout)
    }
}
