import AppKit

/// Thin border overlay showing the capture region during scrolling capture
class ScrollingCaptureHighlight {
    private var window: NSWindow?

    func show(rect: CGRect, on screen: NSScreen) {
        let borderWidth: CGFloat = 2
        let expandedRect = rect.insetBy(dx: -borderWidth, dy: -borderWidth)

        let screenFrame = screen.frame
        let globalRect = CGRect(
            x: rect.origin.x + screenFrame.origin.x - borderWidth,
            y: rect.origin.y + screenFrame.origin.y - borderWidth,
            width: expandedRect.width,
            height: expandedRect.height
        )

        // Reuse existing window if just unhiding
        if let existing = window {
            existing.setFrame(globalRect, display: true)
            existing.orderFrontRegardless()
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: expandedRect.size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .clear
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        w.hidesOnDeactivate = false

        let view = HighlightBorderView(frame: NSRect(origin: .zero, size: expandedRect.size))
        w.contentView = view

        w.setFrame(globalRect, display: true)
        w.orderFrontRegardless()

        self.window = w
    }

    /// Hide the highlight temporarily (e.g. during screen capture)
    func hide() {
        window?.orderOut(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}

class HighlightBorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.7).setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
        path.lineWidth = 2
        path.stroke()
    }
}
