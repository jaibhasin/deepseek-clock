//
//  DeepSeekPricingTests.swift
//  DeepSeekClockTests
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Locks down the published rate card and the rule that off-peak is exactly     │
//  │ half of peak. If someone fat-fingers a price while updating the table, these │
//  │ tests are what catches it.                                                   │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import XCTest
@testable import DeepSeekClock

final class DeepSeekPricingTests: XCTestCase {

    /// DeepSeek defines off-peak as half of peak for every model and every meter.
    func testOffPeakIsExactlyHalfOfPeak() {
        for model in DeepSeekModel.allCases {
            let peak = DeepSeekPricing.peak(for: model)
            let offPeak = DeepSeekPricing.offPeak(for: model)

            XCTAssertEqual(offPeak.inputCacheHit, peak.inputCacheHit / 2, "\(model) cache hit")
            XCTAssertEqual(offPeak.inputCacheMiss, peak.inputCacheMiss / 2, "\(model) cache miss")
            XCTAssertEqual(offPeak.output, peak.output / 2, "\(model) output")
        }
    }

    /// The flash peak rates match the published page.
    func testFlashPeakRates() {
        let pricing = DeepSeekPricing.peak(for: .flash)
        XCTAssertEqual(pricing.inputCacheHit, TestSupport.dec("0.006"))
        XCTAssertEqual(pricing.inputCacheMiss, TestSupport.dec("0.30"))
        XCTAssertEqual(pricing.output, TestSupport.dec("1.20"))
    }

    /// The v4-pro peak rates match the published page.
    func testProPeakRates() {
        let pricing = DeepSeekPricing.peak(for: .pro)
        XCTAssertEqual(pricing.inputCacheHit, TestSupport.dec("0.044"))
        XCTAssertEqual(pricing.inputCacheMiss, TestSupport.dec("1.32"))
        XCTAssertEqual(pricing.output, TestSupport.dec("3.96"))
    }

    /// `pricing(for:phase:)` must dispatch to the right table for the live phase.
    func testPricingResolvesByPhase() {
        for model in DeepSeekModel.allCases {
            XCTAssertEqual(DeepSeekPricing.pricing(for: model, phase: .peak),
                           DeepSeekPricing.peak(for: model))
            XCTAssertEqual(DeepSeekPricing.pricing(for: model, phase: .offPeak),
                           DeepSeekPricing.offPeak(for: model))
        }
    }

    /// Prices format as US dollars, keeping three decimals for sub-cent values.
    func testPriceFormatting() {
        XCTAssertEqual(USDPriceFormatter.string(TestSupport.dec("0.30")), "$0.30")
        XCTAssertEqual(USDPriceFormatter.string(TestSupport.dec("0.006")), "$0.006")
        XCTAssertEqual(USDPriceFormatter.string(TestSupport.dec("3.96")), "$3.96")
    }

    /// Each model has exactly the cases the UI picker expects.
    func testModelDisplayNames() {
        XCTAssertEqual(DeepSeekModel.allCases, [.flash, .pro])
        XCTAssertEqual(DeepSeekModel.flash.displayName, "Flash")
        XCTAssertEqual(DeepSeekModel.pro.displayName, "V4 Pro")
    }
}
