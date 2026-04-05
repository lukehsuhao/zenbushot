import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private var keepAliveTimer: Timer?
    let captureCoordinator = CaptureCoordinator.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Request screen recording permission
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }

        // Request accessibility permission
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        // Setup menu bar
        statusBarController = StatusBarController(coordinator: captureCoordinator)

        // Setup global hotkeys
        hotkeyManager = HotkeyManager(coordinator: captureCoordinator)

        // Apply system shortcut override if enabled
        SystemShortcutOverride.applyCurrentSetting()

        // Keep the run loop alive so CGEvent tap receives events
        // even when there are no visible windows
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // no-op, just keeps the run loop spinning
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Restore macOS screenshot shortcuts when app quits
        SystemShortcutOverride.restore()
    }
}
