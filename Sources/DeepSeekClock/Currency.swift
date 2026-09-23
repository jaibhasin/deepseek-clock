//
//  Currency.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Which currency prices are displayed in.                                      │
//  │                                                                              │
//  │ DeepSeek publishes its rate card in USD. When the user picks another         │
//  │ currency we multiply those USD amounts by an exchange rate (see              │
//  │ `ExchangeRates`), so this type only names a currency and formats money.       │
//  │                                                                              │
//  │ The selectable list comes from the system, not a hard-coded table, so it      │
//  │ stays correct as currencies come and go.                                      │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import Foundation

/// A currency the user can display prices in.
///
/// A value type wrapping an ISO 4217 code (e.g. `"USD"`, `"INR"`). Names are
/// localized by the system; symbols are handled by `CurrencyFormatter`.
struct Currency: Identifiable, Hashable {
    /// ISO 4217 code, always upper-cased (e.g. `"INR"`).
    let code: String

    var id: String { code }

    /// Localized display name, e.g. "Indian Rupee".
    var name: String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    /// US dollars: the base currency DeepSeek prices in.
    static let usd = Currency(code: "USD")

    /// Every currency the system knows about, USD first then the rest sorted by
    /// code so the picker is stable and easy to scan.
    static var selectable: [Currency] {
        let codes = Locale.commonISOCurrencyCodes.filter { $0 != usd.code }.sorted()
        return [usd] + codes.map(Currency.init)
    }

    /// A short list for the top of the picker so the common choices do not require
    /// scrolling through all ~150 currencies. Order is by rough popularity.
    static let common: [Currency] = [
        "USD", "EUR", "GBP", "INR", "CNY", "JPY", "AUD", "CAD",
        "CHF", "HKD", "SGD", "NZD", "KRW", "BRL", "MXN", "ZAR", "SEK", "AED"
    ].map(Currency.init)

    /// `true` when this is the base currency (no conversion needed).
    var isBase: Bool { code == Self.usd.code }

    /// Currencies whose smallest unit is a whole unit (no decimal places).
    private static let zeroDecimalCodes: Set<String> = [
        "JPY", "KRW", "VND", "CLP", "ISK", "HUF"
    ]

    /// How many fraction digits to show for this currency.
    var fractionDigits: Int { Self.zeroDecimalCodes.contains(code) ? 0 : 2 }
}
