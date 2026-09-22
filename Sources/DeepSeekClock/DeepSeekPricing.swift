//
//  DeepSeekPricing.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ The rate card: what DeepSeek charges per 1M tokens, for each model and for   │
//  │ each pricing phase.                                                          │
//  │                                                                              │
//  │ Like `DeepSeekSchedule`, this file is pure data + pure functions: no         │
//  │ SwiftUI, no timers, no network. All the published numbers live in one table, │
//  │ so updating them when DeepSeek changes its prices is a single, obvious edit. │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
//  WHERE THESE NUMBERS COME FROM
//  -----------------------------
//      https://api-docs.deepseek.com/quick_start/pricing
//
//  Prices are quoted in US dollars per 1,000,000 ("1M") tokens and are split into
//  three meters:
//      • input · cache hit   → prompt tokens already in DeepSeek's context cache
//      • input · cache miss  → prompt tokens DeepSeek has to process fresh
//      • output              → tokens the model generates
//
//  DeepSeek publishes off-peak as exactly half of peak. Instead of duplicating the
//  numbers we DERIVE off-peak from peak (see `offPeak(for:)`), so the two phases
//  can never drift apart in the source.
//
//  WHY `Decimal` AND NOT `Double`?
//  -------------------------------
//  These are money values. `Decimal` does base-10 arithmetic, so a value like
//  $0.006 stays exactly 0.006 instead of the tiny binary rounding error a
//  `Double` would carry. That makes both the display and the tests trustworthy.
//
import Foundation

/// The DeepSeek models this app can show prices for.
///
/// `CaseIterable` lets the UI build its model picker without listing the cases a
/// second time, and `Identifiable` gives SwiftUI's `ForEach` a stable id.
enum DeepSeekModel: String, CaseIterable, Identifiable {
    /// `deepseek-flash` — the fast, low-cost model.
    case flash

    /// `deepseek-v4-pro` — the larger, higher-quality model.
    case pro

    /// Stable identifier (the raw value doubles as the persistence key).
    var id: String { rawValue }

    /// Short, friendly name shown in the picker and next to the prices.
    var displayName: String {
        switch self {
        case .flash: return "Flash"
        case .pro:   return "V4 Pro"
        }
    }
}

/// The three billable meters, in USD per 1M tokens.
struct ModelPricing: Equatable {
    let inputCacheHit: Decimal
    let inputCacheMiss: Decimal
    let output: Decimal
}

/// The single source of truth for DeepSeek's published rates.
///
/// This is intentionally an `enum` with no cases: it is a namespace. You can never
/// create an instance, which is exactly right for a stateless lookup table.
enum DeepSeekPricing {

    // MARK: - Rate lookup

    /// Peak (full price) rates for `model`, in USD per 1M tokens.
    static func peak(for model: DeepSeekModel) -> ModelPricing {
        switch model {
        case .flash:
            return ModelPricing(inputCacheHit: usd("0.006"),
                                inputCacheMiss: usd("0.30"),
                                output: usd("1.20"))
        case .pro:
            return ModelPricing(inputCacheHit: usd("0.044"),
                                inputCacheMiss: usd("1.32"),
                                output: usd("3.96"))
        }
    }

    /// Off-peak rates for `model`, in USD per 1M tokens.
    ///
    /// DeepSeek defines off-peak as half of peak, so we compute it rather than
    /// hard-code a second set of numbers that could accidentally go stale.
    static func offPeak(for model: DeepSeekModel) -> ModelPricing {
        let peak = peak(for: model)
        return ModelPricing(inputCacheHit: peak.inputCacheHit / 2,
                            inputCacheMiss: peak.inputCacheMiss / 2,
                            output: peak.output / 2)
    }

    /// Rates for `model` during the given `phase`.
    ///
    /// This is the function the UI calls: give it the model the user picked and
    /// the phase the clock is currently in, and it returns the right row.
    static func pricing(for model: DeepSeekModel, phase: PricingPhase) -> ModelPricing {
        switch phase {
        case .peak:    return peak(for: model)
        case .offPeak: return offPeak(for: model)
        }
    }

    // MARK: - Helpers

    /// Builds a `Decimal` from a decimal string such as `"0.006"`.
    ///
    /// Parsing a string (instead of using a float literal) guarantees the value is
    /// exactly what a human typed in the docs, with no binary rounding surprises.
    private static func usd(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}

/// Formats a USD amount for display, e.g. `0.006` → `"$0.006"`, `0.30` → `"$0.30"`.
///
/// It is a small namespace (no instances) so the formatter — which is relatively
/// expensive to build — is created once and reused.
enum USDPriceFormatter {

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        // Two decimals for normal prices, three for the sub-cent cache-hit rates.
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    /// Returns `value` rendered as a US-dollar string.
    static func string(_ value: Decimal) -> String {
        formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
}
