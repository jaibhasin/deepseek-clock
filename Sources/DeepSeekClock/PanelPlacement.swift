import Foundation

enum PanelPlacement {
    /// Position before presentation, keeping the panel inside the current display.
    static func frame(size: CGSize, below buttonFrame: CGRect, screen: CGRect) -> CGRect {
        let width = min(size.width, screen.width)
        let top = min(buttonFrame.minY, screen.maxY) - 4
        let height = min(size.height, max(0, top - screen.minY))
        let x = min(max(buttonFrame.midX - width / 2, screen.minX), screen.maxX - width)
        return CGRect(x: x, y: top - height, width: width, height: height)
    }
}
