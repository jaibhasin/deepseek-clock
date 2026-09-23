import AppKit
import XCTest
@testable import DeepSeekClock

final class StatusIconTests: XCTestCase {
    @MainActor
    func testMenuBarKeepsTemplateWhaleAndDistinctPhaseColours() {
        let whale = StatusIcon.menuBarImage()
        let offPeakSpout = StatusIcon.spoutImage(for: .offPeak)
        let peakSpout = StatusIcon.spoutImage(for: .peak)

        XCTAssertTrue(whale.isTemplate)
        XCTAssertFalse(offPeakSpout.isTemplate)
        XCTAssertFalse(peakSpout.isTemplate)
        XCTAssertEqual(whale.size, offPeakSpout.size)
        XCTAssertEqual(whale.size, peakSpout.size)

        let offPeakPixels = offPeakSpout.tiffRepresentation
        let peakPixels = peakSpout.tiffRepresentation
        XCTAssertNotNil(offPeakPixels)
        XCTAssertNotNil(peakPixels)
        XCTAssertNotEqual(offPeakPixels, peakPixels)
    }
}
