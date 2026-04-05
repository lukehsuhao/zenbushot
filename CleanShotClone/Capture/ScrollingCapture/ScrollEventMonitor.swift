import AppKit

class ScrollEventMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var debounceTimer: Timer?
    var onScrollSettled: (() -> Void)?

    func start() {
        // Use NSEvent monitors for scroll wheel events
        // Both global (other apps) and local (our app) to catch all scroll events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] _ in
            self?.handleScrollEvent()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent()
            return event
        }
        NSLog("[ScrollMonitor] started (NSEvent monitors)")
    }

    private func handleScrollEvent() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            NSLog("[ScrollMonitor] scroll settled, firing callback")
            self?.onScrollSettled?()
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
        debounceTimer?.invalidate()
        debounceTimer = nil
        onScrollSettled = nil
        NSLog("[ScrollMonitor] stopped")
    }

    static func postScroll(deltaY: Int32) {
        if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: deltaY, wheel2: 0, wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }

    static func postScrollLines(lines: Int32) {
        if let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: lines, wheel2: 0, wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }
}
