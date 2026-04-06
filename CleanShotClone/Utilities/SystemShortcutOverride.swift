import Foundation
import AppKit

/// Disables/re-enables macOS built-in screenshot shortcuts (Cmd+Shift+3/4/5)
/// Modifies the symbolic hotkeys plist - requires logout/login to fully take effect
class SystemShortcutOverride {

    private static let hotkeyIDs = [28, 29, 30, 31, 184]

    static func apply(override: Bool) {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.symbolichotkeys.plist"

        for id in hotkeyIDs {
            let keyPath = ":AppleSymbolicHotKeys:\(id):enabled"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/libexec/PlistBuddy")
            task.arguments = ["-c", "Set \(keyPath) \(!override)", plistPath]
            try? task.run()
            task.waitUntilExit()
        }

        NSLog("[SystemShortcutOverride] \(override ? "disabled" : "enabled") macOS screenshot shortcuts in plist")

        if override {
            // Show alert telling user to logout
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Restart Required"
                alert.informativeText = "macOS screenshot shortcuts have been disabled in settings. Please log out and log back in (or restart) for this to take effect.\n\nAfter restarting, Cmd+Shift+3/4/5 will only trigger ZenbuShot."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Log Out Now")
                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    // Log out
                    let script = "tell application \"System Events\" to log out"
                    if let appleScript = NSAppleScript(source: script) {
                        var error: NSDictionary?
                        appleScript.executeAndReturnError(&error)
                    }
                }
            }
        }
    }

    static func applyCurrentSetting() {
        // On launch, silently apply if already enabled (plist already modified)
        // No alert needed since user already restarted
    }

    static func restore() {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.symbolichotkeys.plist"
        for id in hotkeyIDs {
            let keyPath = ":AppleSymbolicHotKeys:\(id):enabled"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/libexec/PlistBuddy")
            task.arguments = ["-c", "Set \(keyPath) true", plistPath]
            try? task.run()
            task.waitUntilExit()
        }
        NSLog("[SystemShortcutOverride] restored macOS screenshot shortcuts")
    }
}
