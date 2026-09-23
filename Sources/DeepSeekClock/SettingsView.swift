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

            if !clock.selectedCurrency.isBase {
                Link("Rates by ExchangeRate-API",
                     destination: URL(string: "https://www.exchangerate-api.com/")!)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
            }
        }
    }

    // MARK: - Time zone

    @ViewBuilder private var timeZoneMenuItems: some View {
        Button {
            clock.displayTimeZone = .system
        } label: {
            choiceLabel("System", isSelected: clock.displayTimeZone.isSystem)
        }
        Divider()
        ForEach(DisplayTimeZone.groupedIdentifiers(), id: \.region) { group in
            Menu(group.region) {
                ForEach(group.identifiers, id: \.self) { identifier in
                    Button {
                        clock.displayTimeZone = DisplayTimeZone(identifier: identifier)
                    } label: {
                        let title = TimeZone(identifier: identifier)
                            .map(DisplayTimeZone.label(for:)) ?? identifier
                        choiceLabel(title, isSelected: clock.displayTimeZone.identifier == identifier)
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
        ForEach(Currency.common) { currency in
            Button {
                clock.selectedCurrency = currency
            } label: {
                choiceLabel("\(currency.code) · \(currency.name)",
                            isSelected: clock.selectedCurrency == currency)
            }
        }
        Divider()
        Menu("All currencies") {
            ForEach(Currency.selectable) { currency in
                Button {
                    clock.selectedCurrency = currency
                } label: {
                    choiceLabel("\(currency.code) · \(currency.name)",
                                isSelected: clock.selectedCurrency == currency)
                }
            }
        }
    }

    /// A short line describing the freshness of the exchange rates, or `nil` when
    /// the base currency needs no rate at all.
    private var rateStatus: String? {
        guard !clock.selectedCurrency.isBase else { return nil }

        let code = clock.selectedCurrency.code
        if let rates = clock.exchangeRates, let rate = rates.rate(for: code) {
            let one = CurrencyFormatter.string(1, currency: .usd)
            let converted = CurrencyFormatter.string(rate, currency: clock.selectedCurrency)
            let age = relative(rate: rates)
            if clock.isRefreshingRates { return "Using saved rate · updated \(age)" }
            if clock.didFailRates { return "Update failed · using rate from \(age)" }
            return "\(one) = \(converted) · updated \(age)"
        }
        if clock.isRefreshingRates { return "Loading exchange rates…" }
        if clock.didFailRates { return "Rates unavailable - showing USD" }
        if clock.exchangeRates != nil { return "No rate for \(code) - showing USD" }
        return "Loading exchange rates…"
    }

    private func relative(rate: ExchangeRates) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: rate.updatedAt, relativeTo: Date())
    }

    private func rateStatusRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func choiceLabel(_ title: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 16)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
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
