import XCTest
@testable import DeepSeekClock

final class PanelPlacementTests: XCTestCase {
    private let size = CGSize(width: 292, height: 380)
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 876)

    func testPanelOpensCenteredBelowButtonWithGap() {
        let button = CGRect(x: 700, y: 876, width: 28, height: 24)
        let result = PanelPlacement.frame(size: size, below: button, screen: screen)
        XCTAssertEqual(result.maxY, button.minY - 4)
        XCTAssertEqual(result.midX, button.midX)
        XCTAssertEqual(result.size, size)
    }

    func testPanelStaysWithinBothScreenEdges() {
        for x in [CGFloat(0), CGFloat(1412)] {
            let button = CGRect(x: x, y: 876, width: 28, height: 24)
            let result = PanelPlacement.frame(size: size, below: button, screen: screen)
            XCTAssertTrue(screen.contains(result))
        }
    }

    func testPanelUsesSecondaryDisplayCoordinates() {
        let screen = CGRect(x: -1440, y: -900, width: 1440, height: 870)
        let button = CGRect(x: -500, y: -30, width: 28, height: 30)
        let result = PanelPlacement.frame(size: size, below: button, screen: screen)
        XCTAssertEqual(result.maxY, -34)
        XCTAssertEqual(result.midX, button.midX)
        XCTAssertTrue(screen.contains(result))
    }

    func testPanelFitsSmallDisplay() {
        let screen = CGRect(x: 0, y: 0, width: 250, height: 300)
        let button = CGRect(x: 100, y: 300, width: 28, height: 24)
        let result = PanelPlacement.frame(size: size, below: button, screen: screen)
        XCTAssertTrue(screen.contains(result))
    }
}
