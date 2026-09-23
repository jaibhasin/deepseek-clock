//
//  SettingsView.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ The inline settings screen shown inside the dropdown panel.                  │
//  │                                                                              │
//  │ It is deliberately compact: one short row per preference, each with a         │
//  │ native menu for changing it. Two preferences exist today:                     │
//  │     • Time zone — which clock transition times are shown in                   │
//  │     • Currency  — which currency prices are converted into                    │
//  │                                                                              │
//  │ DeepSeek's schedule itself is always UTC, so neither setting can change       │
//  │ whether pricing is peak or off-peak.                                          │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import SwiftUI

struct SettingsView: View {
    @ObservedObject var clock: ClockModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingRow(title: "Time zone",
                       value: clock.displayTimeZone.displayName) {
                timeZoneMenuItems
            }

            settingRow(title: "Currency",
                       value: currencyValue) {
                currencyMenuItems
            }

            if let status = rateStatus {
                rateStatusRow(status)
            }
        }
    }

    // MARK: - Time zone

    @ViewBuilder private var timeZoneMenuItems: some View {
        Button("System") { clock.displayTimeZone = .system }
        Divider()
        ForEach(DisplayTimeZone.groupedIdentifiers(), id: \.region) { group in
            Menu(group.region) {
                ForEach(group.identifiers, id: \.self) { identifier in
                    Button(identifier.replacingOccurrences(of: "_", with: " ")) {
                        clock.displayTimeZone = DisplayTimeZone(identifier: identifier)
                    }
                }
            }
        }
    }

    // MARK: - Currency

    private var currencyValue: String {
        "\(clock.selectedCurrency.code) · \(clock.selectedCurrency.name)"
    }

    @ViewBuilder private var currencyMenuItems: some View {
        ForEach(Currency.selectable) { currency in
            Button("\(currency.code) · \(currency.name)") {
                clock.selectedCurrency = currency
            }
        }
    }

    /// A short line describing the freshness of the exchange rates, or `nil` when
    /// the base currency needs no rate at all.
    private var rateStatus: String? {
        guard !clock.selectedCurrency.isBase else { return nil }

        let code = clock.selectedCurrency.code
        if clock.isRefreshingRates { return "Updating rates…" }
        if let rates = clock.exchangeRates, let rate = rates.rate(for: code) {
            let one = CurrencyFormatter.string(1, currency: .usd)
            let converted = CurrencyFormatter.string(rate, currency: clock.selectedCurrency)
            return "\(one) = \(converted) · \(relative(rate: rates, code: code))"
        }
        if clock.didFailRates { return "Rates unavailable — showing USD" }
        if clock.exchangeRates != nil { return "No rate for \(code) — showing USD" }
        return nil
    }

    private func relative(rate: ExchangeRates, code: String) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "updated \(formatter.localizedString(for: rate.updatedAt, relativeTo: Date()))"
    }

    private func rateStatusRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Button {
                clock.refreshRates()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(clock.isRefreshingRates)
            .help("Refresh exchange rates")
            .accessibilityLabel("Refresh exchange rates")
        }
    }

    // MARK: - Shared row chrome

    private var changeLabel: some View {
        HStack(spacing: 3) {
            Text("Change")
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .semibold))
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.tint)
        .fixedSize()
    }

    private func settingRow<Content: View>(title: String,
                                           value: String,
                                           @ViewBuilder menu: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Menu {
                menu()
            } label: {
                changeLabel
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(10)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}
