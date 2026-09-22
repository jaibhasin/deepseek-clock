import AppKit
import SwiftUI
import XCTest
@testable import DeepSeekClock

final class StatusPanelTests: XCTestCase {
    @MainActor
    func testPanelCanOpenWithoutActivatingApp() {
        let panel = StatusPanel()

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(panel.becomesKeyOnlyIfNeeded)
        XCTAssertGreaterThan(panel.frame.width, 0)
        XCTAssertGreaterThan(panel.frame.height, 0)
    }

    @MainActor
    func testContentCanBeMeasuredBeforePanelIsShown() {
        let panel = StatusPanel()
        let content = NSHostingController(rootView: Text("Pricing").frame(width: 292, height: 380))
        panel.contentViewController = content

        let size = content.sizeThatFits(in: NSSize(width: 292, height: 876))

        XCTAssertFalse(panel.isVisible)
        XCTAssertEqual(size.width, 292, accuracy: 0.5)
        XCTAssertEqual(size.height, 380, accuracy: 0.5)
    }
}
