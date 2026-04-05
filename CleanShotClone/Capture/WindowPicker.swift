import AppKit
import CoreGraphics

struct WindowInfo {
    let windowID: CGWindowID
    let name: String
    let ownerName: String
    let bounds: CGRect
}

class WindowPicker {
    private var overlayWindows: [NSWindow] = []
    private var highlightWindow: NSWindow?
    private var eventMonitor: Any?
    private var moveMonitor: Any?
    private var escapeMonitor: Any?
    private let completionHandler: (CGWindowID) -> Void
    private let cancelHandler: () -> Void
    private var availableWindows: [WindowInfo] = []

    init(completionHandler: @escaping (CGWindowID) -> Void, cancelHandler: @escaping () -> Void) {
        self.completionHandler = completionHandler
        self.cancelHandler = cancelHandler
    }

    func show() {
        availableWindows = getWindowList()

        // Create transparent overlay on each screen to capture clicks
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.1)
            window.ignoresMouseEvents = false
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }

        // Monitor mouse movement for highlighting
        moveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
            return event
        }

        // Monitor clicks
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleClick(event)
            return nil
        }

        // Monitor escape
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancelHandler()
                return nil
            }
            return event
        }

        NSCursor.pointingHand.push()
    }

    func dismiss() {
        NSCursor.pop()
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = moveMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = escapeMonitor { NSEvent.removeMonitor(monitor) }
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        highlightWindow?.orderOut(nil)
        highlightWindow = nil
    }

    private func handleMouseMove(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation

        // Find window under cursor
        if let windowInfo = windowUnderPoint(mouseLocation) {
            showHighlight(for: windowInfo)
        } else {
            highlightWindow?.orderOut(nil)
        }
    }

    private func handleClick(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation

        if let windowInfo = windowUnderPoint(mouseLocation) {
            completionHandler(windowInfo.windowID)
        } else {
            cancelHandler()
        }
    }

    private func windowUnderPoint(_ point: NSPoint) -> WindowInfo? {
        // Convert from AppKit coordinates (origin bottom-left) to CG coordinates (origin top-left)
        guard let mainScreen = NSScreen.main else { return nil }
        let cgPoint = CGPoint(x: point.x, y: mainScreen.frame.height - point.y)

        return availableWindows.first { info in
            info.bounds.contains(cgPoint)
        }
    }

    private func showHighlight(for windowInfo: WindowInfo) {
        guard let mainScreen = NSScreen.main else { return }

        // Convert CG coordinates to AppKit coordinates
        let appKitRect = CGRect(
            x: windowInfo.bounds.origin.x,
            y: mainScreen.frame.height - windowInfo.bounds.origin.y - windowInfo.bounds.height,
            width: windowInfo.bounds.width,
            height: windowInfo.bounds.height
        )

        if highlightWindow == nil {
            let hw = NSWindow(
                contentRect: appKitRect,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            hw.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
            hw.isOpaque = false
            hw.backgroundColor = .clear
            hw.ignoresMouseEvents = true

            let view = HighlightView(frame: NSRect(origin: .zero, size: appKitRect.size))
            hw.contentView = view
            highlightWindow = hw
        }

        highlightWindow?.setFrame(appKitRect, display: true)
        highlightWindow?.orderFront(nil)
    }

    private func getWindowList() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap { info -> WindowInfo? in
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"],
                  w > 50 && h > 50, // Filter tiny windows
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0 // Normal windows only
            else { return nil }

            let name = info[kCGWindowName as String] as? String ?? ""
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""

            // Skip our own windows
            if owner == "AnyShot" { return nil }

            return WindowInfo(
                windowID: windowID,
                name: name,
                ownerName: owner,
                bounds: CGRect(x: x, y: y, width: w, height: h)
            )
        }
    }
}

// MARK: - Highlight View

class HighlightView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.systemBlue.withAlphaComponent(0.2).setFill()
        bounds.fill()

        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
        path.lineWidth = 3
        path.stroke()
    }
}
