import SwiftUI
import AppKit

/// Presentation only; pricing, timing, and model selection come from ClockModel.
struct StatusView: View {
    @ObservedObject var clock: ClockModel
    @Environment(\.colorScheme) private var colorScheme

    // Keep small status text legible on both light and dark surfaces.
    private var statusColor: Color {
        switch clock.phase {
        case .offPeak:
            return colorScheme == .dark
                ? Color(red: 0.38, green: 0.85, blue: 0.59)
                : Color(red: 0.08, green: 0.43, blue: 0.25)
        case .peak:
            return colorScheme == .dark
                ? Color(red: 1, green: 0.55, blue: 0.52)
                : Color(red: 0.72, green: 0.18, blue: 0.16)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if clock.isShowingSettings {
                SettingsView(clock: clock)
            } else {
                hero
                VStack(alignment: .leading, spacing: 6) {
                    pricing
                    Text("Reasoning mode affects token usage, not the rates")
                        .font(.system(size: 10))
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.leading, 3)
                }
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 292)
        .background {
            ZStack {
                PopoverVisualEffect()
                Color(nsColor: .windowBackgroundColor)
                    .opacity(colorScheme == .dark ? 0.28 : 0.38)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
        }
    }

    @ViewBuilder private var header: some View {
        if clock.isShowingSettings {
            HStack(spacing: 9) {
                Button {
                    clock.isShowingSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Back")

                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()
            }
        } else {
            HStack(spacing: 9) {
                Image(nsImage: StatusIcon.image(for: clock.phase, size: 24))
                    .accessibilityHidden(true)
                Text("DeepSeek Clock")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 5, height: 5)
                    Text(clock.phase == .offPeak ? "Off-peak" : "Peak")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(statusColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.1), in: Capsule())
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(clock.phase.subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(statusColor)

            Text(clock.countdown)
                .font(.system(size: 42, weight: .medium, design: .rounded))
                .monospacedDigit()
                .tracking(-1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel("\(clock.phase.changeLabel) \(clock.countdown)")

            HStack(spacing: 4) {
                Text(clock.phase == .offPeak ? "Off-peak ends" : "Standard rates end")
                if let transition = clock.formattedTransition {
                    Text("at \(transition)")
                }
                if let zone = clock.displayTimeZone.shortLabel {
                    Text("(\(zone))")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private var pricing: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current rates")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(clock.displayPricing.currency.code) / 1M tokens")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Picker("Model", selection: $clock.selectedModel) {
                ForEach(DeepSeekModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                priceRow("Input · cache hit", clock.displayPricing.prices.inputCacheHit)
                priceRow("Input · cache miss", clock.displayPricing.prices.inputCacheMiss)
                Divider()
                priceRow("Output", clock.displayPricing.prices.output)
            }
        }
        .padding(12)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        }
    }

    private func priceRow(_ label: String, _ value: Decimal) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(CurrencyFormatter.string(value, currency: clock.displayPricing.currency))
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .font(.system(size: 11))
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack {
            Button(action: openConsole) {
                HStack(spacing: 5) {
                    Text("DeepSeek Console")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .help("Open the DeepSeek Console in your browser")

            Spacer()

            Button {
                clock.isShowingSettings.toggle()
            } label: {
                Image(systemName: clock.isShowingSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 12, weight: .medium))
            }
            .help(clock.isShowingSettings ? "Close settings" : "Settings")
            .accessibilityLabel(clock.isShowingSettings ? "Close settings" : "Settings")

            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .font(.system(size: 11, weight: .medium))
    }

    private func openConsole() {
        guard let url = URL(string: "https://platform.deepseek.com") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Uses the same adaptive translucency as native macOS popovers. A light neutral
/// wash above it keeps text contrast stable over bright or saturated wallpapers.
private struct PopoverVisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
