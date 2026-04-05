import AppKit

/// Shows a subtle dim overlay around the recording area so the user knows what's being recorded
class RecordingAreaOverlay {
    private var windows: [NSWindow] = []

    func show(rect: CGRect, screen: NSScreen) {
        let screenFrame = screen.frame

        // Convert CG rect (top-left origin) to AppKit (bottom-left origin)
        let appKitRect = CGRect(
            x: rect.origin.x,
            y: screenFrame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        // Create a window covering the entire screen with a cutout
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: screenFrame.size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false

        let view = RecordingDimView(frame: NSRect(origin: .zero, size: screenFrame.size))
        view.recordingRect = appKitRect
        window.contentView = view
        window.setFrame(screenFrame, display: true)
        window.orderFrontRegardless()

        windows.append(window)
    }

    func dismiss() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

class RecordingDimView: NSView {
    var recordingRect: CGRect = .zero

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Dim overlay with cutout using even-odd fill
        let outerPath = CGMutablePath()
        outerPath.addRect(bounds)
        outerPath.addRoundedRect(in: recordingRect, cornerWidth: 4, cornerHeight: 4)

        context.addPath(outerPath)
        context.setFillColor(NSColor.black.withAlphaComponent(0.15).cgColor)
        context.fillPath(using: .evenOdd)

        // Subtle border around recording area
        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.5)
        let borderPath = CGPath(roundedRect: recordingRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(borderPath)
        context.strokePath()
    }
}
