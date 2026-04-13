import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.backgroundColor = .windowBackgroundColor
        self.isOpaque = false
        self.hasShadow = true
        self.minSize = NSSize(width: 320, height: 400)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        self.animationBehavior = .utilityWindow

        // Only keep the close button
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // Position in top-right of main screen
        positionTopRight()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let x = screenRect.maxX - frame.width - 20
        let y = screenRect.maxY - frame.height - 20
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
