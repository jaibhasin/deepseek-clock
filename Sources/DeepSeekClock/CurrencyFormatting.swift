//
//  CurrencyFormatting.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Turns DeepSeek's USD prices into the currency the user chose, and renders     │
//  │ money for display.                                                           │
//  │                                                                              │
//  │ All pure functions: conversion is `USD × rate`, and formatting is a           │
//  │ `NumberFormatter`. No UI, no networking, so both are unit-testable.           │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import Foundation

/// A rate card already resolved to the currency the user wants to see.
struct DisplayPricing: Equatable {
    let prices: ModelPricing
    let currency: Currency

    /// `true` when the user asked for a non-USD currency but no exchange rate was
    /// available, so the raw USD prices are shown instead.
    let isFallback: Bool
}

/// Converts USD `ModelPricing` into a target currency.
enum CurrencyConverter {

    /// Resolves `usd` into `currency` using `rates`.
    ///
    /// Falls back to USD when the currency is the base or its rate is missing, so
    /// the UI always has a number to show.
    static func display(_ usd: ModelPricing,
                        currency: Currency,
                        rates: ExchangeRates?) -> DisplayPricing {
        guard !currency.isBase else {
            return DisplayPricing(prices: usd, currency: .usd, isFallback: false)
        }
        guard let rate = rates?.rate(for: currency.code) else {
            return DisplayPricing(prices: usd, currency: .usd, isFallback: true)
        }
        let scaled = ModelPricing(
            inputCacheHit: usd.inputCacheHit * rate,
            inputCacheMiss: usd.inputCacheMiss * rate,
            output: usd.output * rate
        )
        return DisplayPricing(prices: scaled, currency: currency, isFallback: false)
    }
}

/// Renders money in a given currency, reusing one `NumberFormatter`.
///
/// `NumberFormatter` is comparatively expensive, and prices redraw every second
/// while the panel is open, so we build it once and only change its currency.
enum CurrencyFormatter {

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        return formatter
    }()

    /// `0.006` in USD → `"$0.006"`; `83.4` in INR → `"₹83.40"`.
    static func string(_ value: Decimal, currency: Currency) -> String {
        formatter.currencyCode = currency.code
        // The base currency needs a third decimal for DeepSeek's sub-cent cache
        // rates; converted amounts are large enough for the currency's normal
        // number of decimals.
        formatter.minimumFractionDigits = currency.isBase ? 2 : currency.fractionDigits
        formatter.maximumFractionDigits = currency.isBase ? 3 : currency.fractionDigits
        return formatter.string(from: value as NSDecimalNumber) ?? "\(currency.code) \(value)"
    }
}
