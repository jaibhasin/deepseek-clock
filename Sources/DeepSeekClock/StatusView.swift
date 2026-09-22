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
//  LAYOUT PRIORITY
//  ---------------
//  The single most important thing a user wants is "when does the price change?".
//  So the countdown is the hero of this panel: large, coloured and near the top.
//  The rate card is supporting detail, pushed below the fold and rendered in a
//  calmer, smaller style so it never competes for attention.
//
import SwiftUI
import AppKit

struct StatusView: View {

    // `@ObservedObject` (not `@StateObject`) because the AppDelegate owns the
    // model; this view only observes it and refreshes when it changes.
    @ObservedObject var clock: ClockModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            hero
            Divider()
            pricing
            Divider()
            quitButton
        }
        .padding(14)
        .frame(width: 260)
    }

    // MARK: - Header

    /// The DeepSeek whale tinted green/red, plus the plain-English phase name.
    private var header: some View {
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
    }

    // MARK: - Hero: when the price changes

    /// The focal point of the panel. A big countdown plus the local clock time it
    /// lands on, so the answer to "when?" is readable at a glance.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(clock.phase.changeLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(clock.countdown)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(clock.phase.color)

            // The transition rendered in the Mac's own time zone.
            if let transition = clock.formattedTransition {
                Text("at \(transition)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Supporting detail: rates

    /// The rate card, deliberately quieter than the hero: smaller type, muted
    /// labels, and its own model picker so both models fit without crowding.
    private var pricing: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pricing")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("USD per 1M tokens")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Picker("Model", selection: $clock.selectedModel) {
                ForEach(DeepSeekModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(spacing: 3) {
                priceRow("Input · cache hit", clock.currentPricing.inputCacheHit)
                priceRow("Input · cache miss", clock.currentPricing.inputCacheMiss)
                priceRow("Output", clock.currentPricing.output)
            }
        }
    }

    /// One "label .................. $0.30" line of the rate card.
    ///
    /// The value is rendered with `USDPriceFormatter` so every price uses the
    /// same currency style, and `monospacedDigit()` keeps the decimal points
    /// aligned as the numbers change when the phase flips.
    private func priceRow(_ label: String, _ value: Decimal) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(USDPriceFormatter.string(value))
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    // MARK: - Footer

    /// A menu bar app has no window to close, so it needs an explicit way to quit.
    /// Cmd-Q also works while the panel is focused.
    private var quitButton: some View {
        Button("Quit DeepSeek Clock") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
        .controlSize(.small)
    }
}
