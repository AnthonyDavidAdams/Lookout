import AppKit

/// Transparent, click-through overlay window for drawing highlights on the screen.
final class OverlayWindow: NSWindow {

    private var highlightView: HighlightOverlayView?
    private var dismissTimer: Timer?

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isReleasedWhenClosed = false

        let view = HighlightOverlayView(frame: screen.frame)
        self.contentView = view
        self.highlightView = view
    }

    /// Show a pulsing highlight circle at the given screen coordinates.
    func showHighlight(at point: NSPoint, radius: CGFloat = 30, label: String? = nil, duration: TimeInterval = 5) {
        guard let screen = NSScreen.main else { return }

        // Reposition to cover the screen
        self.setFrame(screen.frame, display: true)

        // Convert screen coordinates to window-local
        let localPoint = NSPoint(
            x: point.x - screen.frame.origin.x,
            y: point.y - screen.frame.origin.y
        )

        highlightView?.highlight = HighlightOverlayView.Highlight(
            center: localPoint,
            radius: radius,
            label: label
        )
        highlightView?.needsDisplay = true

        self.orderFrontRegardless()

        // Start pulse animation
        highlightView?.startPulsing()

        // Auto-dismiss
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismissHighlight()
        }
    }

    func dismissHighlight() {
        dismissTimer?.invalidate()
        highlightView?.stopPulsing()
        highlightView?.highlight = nil
        highlightView?.needsDisplay = true
        self.orderOut(nil)
    }
}

/// Custom view that draws the highlight circle + arrow.
final class HighlightOverlayView: NSView {

    struct Highlight {
        let center: NSPoint
        let radius: CGFloat
        let label: String?
    }

    var highlight: Highlight?
    private var pulseTimer: Timer?
    private var pulsePhase: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let h = highlight else { return }

        // Dim the screen slightly around the highlight
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.15).cgColor)
        ctx.fill(bounds)

        // Cut out a clear circle around the highlight
        let clearRect = NSRect(
            x: h.center.x - h.radius * 2,
            y: h.center.y - h.radius * 2,
            width: h.radius * 4,
            height: h.radius * 4
        )
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: clearRect)
        ctx.setBlendMode(.normal)

        // Draw pulsing ring
        let ringRadius = h.radius * 1.5 + pulsePhase * 8
        let ringAlpha = max(0, 0.7 - pulsePhase * 0.5)

        ctx.setStrokeColor(NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: ringAlpha).cgColor)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: NSRect(
            x: h.center.x - ringRadius,
            y: h.center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        ))

        // Inner solid ring
        ctx.setStrokeColor(NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.9).cgColor)
        ctx.setLineWidth(2.5)
        ctx.strokeEllipse(in: NSRect(
            x: h.center.x - h.radius * 1.3,
            y: h.center.y - h.radius * 1.3,
            width: h.radius * 2.6,
            height: h.radius * 2.6
        ))

        // Arrow pointing down to the highlight
        let arrowTip = NSPoint(x: h.center.x, y: h.center.y + h.radius * 1.8)
        let arrowBase = NSPoint(x: h.center.x, y: h.center.y + h.radius * 4)

        ctx.setStrokeColor(NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.9).cgColor)
        ctx.setLineWidth(3)
        ctx.move(to: arrowBase)
        ctx.addLine(to: arrowTip)
        ctx.strokePath()

        // Arrow head
        ctx.move(to: arrowTip)
        ctx.addLine(to: NSPoint(x: arrowTip.x - 8, y: arrowTip.y + 12))
        ctx.move(to: arrowTip)
        ctx.addLine(to: NSPoint(x: arrowTip.x + 8, y: arrowTip.y + 12))
        ctx.strokePath()

        // Label
        if let label = h.label, !label.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 0.85),
            ]
            let str = NSAttributedString(string: "  \(label)  ", attributes: attrs)
            let size = str.size()
            let labelOrigin = NSPoint(
                x: h.center.x - size.width / 2,
                y: h.center.y + h.radius * 4.5
            )
            str.draw(at: labelOrigin)
        }
    }

    func startPulsing() {
        pulsePhase = 0
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.pulsePhase += 0.02
            if self.pulsePhase > 1.0 { self.pulsePhase = 0 }
            self.needsDisplay = true
        }
    }

    func stopPulsing() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}
