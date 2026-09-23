import AppKit
import XCTest
@testable import DeepSeekClock

final class StatusIconTests: XCTestCase {
    @MainActor
    func testAllEightIconsKeepNativeTemplateContrastAndPhaseColour() {
        XCTAssertEqual(MenuBarIconStyle.allCases.count, 8)
        XCTAssertTrue(StatusIcon.hasOfficialArtwork)

        for style in MenuBarIconStyle.allCases {
            let shape = StatusIcon.menuBarImage(for: style)
            let offPeak = StatusIcon.accentImage(for: style, phase: .offPeak)
            let peak = StatusIcon.accentImage(for: style, phase: .peak)

            XCTAssertTrue(shape.isTemplate, style.displayName)
            XCTAssertEqual(shape.size, NSSize(width: 18, height: 18))
            if style.showsPricingColor {
                guard let offPeak, let peak else {
                    XCTFail("Missing accent for \(style.displayName)")
                    continue
                }
                XCTAssertFalse(offPeak.isTemplate)
                XCTAssertFalse(peak.isTemplate)
                XCTAssertEqual(offPeak.size, shape.size)
                XCTAssertNotEqual(offPeak.tiffRepresentation, peak.tiffRepresentation,
                                  style.displayName)
            } else {
                XCTAssertNil(offPeak, style.displayName)
                XCTAssertNil(peak, style.displayName)
            }
        }
    }
}
