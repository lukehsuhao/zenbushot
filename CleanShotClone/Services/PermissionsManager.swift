import AppKit
import CoreGraphics

class PermissionsManager {
    static let shared = PermissionsManager()

    func checkAndRequestPermissions() {
        // Request screen recording
        if !hasScreenRecordingPermission {
            CGRequestScreenCaptureAccess()
        }
        // Request accessibility
        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
        }
    }

    /// Practical check: capture a tiny area and verify it has real content.
    /// CGWindowListCreateImage returns a blank/black image when permission is denied.
    var hasScreenRecordingPermission: Bool {
        // Try CGPreflightScreenCaptureAccess first (fast path)
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        // Fallback: practical test — capture 1x1 pixel and check it's not all-zero
        guard let image = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            []
        ) else { return false }

        // Check if the image has actual content (not blank)
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              CFDataGetLength(data) > 0 else { return false }

        let ptr = CFDataGetBytePtr(data)
        let length = min(CFDataGetLength(data), 4)

        // If all bytes are 0, likely permission denied (blank capture)
        var allZero = true
        for i in 0..<length {
            if ptr?[i] != 0 { allZero = false; break }
        }

        return !allZero
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func showPermissionAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
