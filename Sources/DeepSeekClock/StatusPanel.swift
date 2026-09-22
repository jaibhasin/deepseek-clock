import AppKit

/// An arrowless menu bar panel that accepts keyboard shortcuts and SwiftUI controls.
final class StatusPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 292, height: 380),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
