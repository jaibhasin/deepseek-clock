//
//  CurrencyTests.swift
//  DeepSeekClockTests
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Tests the pure currency pieces: USD → currency conversion, exchange-rate      │
//  │ staleness, and the on-disk cache. No networking happens here — the service    │
//  │ is behind a protocol precisely so it never needs to.                          │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import XCTest
@testable import DeepSeekClock

final class CurrencyTests: XCTestCase {

    private let usdPricing = ModelPricing(inputCacheHit: TestSupport.dec("0.006"),
                                          inputCacheMiss: TestSupport.dec("0.30"),
                                          output: TestSupport.dec("1.20"))

    private func rates(_ values: [String: Double], updated: Date = Date()) -> ExchangeRates {
        ExchangeRates(baseCode: "USD", rates: values, updatedAt: updated)
    }

    // MARK: - Conversion

    /// USD needs no rate at all and must be returned untouched.
    func testBaseCurrencyIsUnchanged() {
        let result = CurrencyConverter.display(usdPricing, currency: .usd, rates: nil)
        XCTAssertEqual(result.prices, usdPricing)
        XCTAssertEqual(result.currency, .usd)
        XCTAssertFalse(result.isFallback)
    }

    /// A known rate scales every meter by that rate.
    func testConvertsEachMeterByTheRate() {
        let result = CurrencyConverter.display(usdPricing,
                                               currency: Currency(code: "INR"),
                                               rates: rates(["INR": 80]))
        XCTAssertEqual(result.prices.inputCacheHit, TestSupport.dec("0.48"))
        XCTAssertEqual(result.prices.inputCacheMiss, TestSupport.dec("24"))
        XCTAssertEqual(result.prices.output, TestSupport.dec("96"))
        XCTAssertEqual(result.currency.code, "INR")
        XCTAssertFalse(result.isFallback)
    }

    /// A missing rate falls back to USD and says so, so the UI can warn.
    func testMissingRateFallsBackToUSD() {
        let result = CurrencyConverter.display(usdPricing,
                                               currency: Currency(code: "EUR"),
                                               rates: rates(["INR": 80]))
        XCTAssertEqual(result.prices, usdPricing)
        XCTAssertEqual(result.currency, .usd)
        XCTAssertTrue(result.isFallback)
    }

    // MARK: - ExchangeRates

    /// `rate(for:)` returns a Decimal built without binary rounding noise.
    func testRateLookup() {
        let snapshot = rates(["INR": 83.12])
        XCTAssertEqual(snapshot.rate(for: "INR"), TestSupport.dec("83.12"))
        XCTAssertNil(snapshot.rate(for: "ZZZ"))
    }

    /// A snapshot older than the maximum age is stale; a fresh one is not.
    func testStaleness() {
        let now = TestSupport.utc(2026, 9, 21, 12, 0)
        let fresh = rates(["INR": 1], updated: now.addingTimeInterval(-60))
        let old = rates(["INR": 1], updated: now.addingTimeInterval(-13 * 60 * 60))

        XCTAssertFalse(fresh.isStale(now: now))
        XCTAssertTrue(old.isStale(now: now))
    }

    // MARK: - Cache

    /// Saving then loading round-trips the snapshot through `UserDefaults`.
    func testStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "CurrencyTests-\(UUID().uuidString)")!
        let store = ExchangeRateStore(defaults: defaults)
        let snapshot = rates(["INR": 83.12], updated: TestSupport.utc(2026, 9, 21, 0, 0))

        XCTAssertNil(store.load())
        store.save(snapshot)
        XCTAssertEqual(store.load(), snapshot)
    }

    // MARK: - Formatting

    /// The base currency keeps a third decimal for DeepSeek's sub-cent rates.
    func testBaseFormattingKeepsSubCentPrecision() {
        XCTAssertEqual(CurrencyFormatter.string(TestSupport.dec("0.006"), currency: .usd),
                       "$0.006")
    }
}
