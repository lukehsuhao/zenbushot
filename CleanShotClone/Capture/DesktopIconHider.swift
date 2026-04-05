import AppKit

class DesktopIconHider {
    static let shared = DesktopIconHider()
    private(set) var isHidden = false

    init() {
        // Restore desktop icons on app quit
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification, object: nil
        )
    }

    func toggle() {
        if isHidden { show() } else { hide() }
    }

    func hide() {
        guard !isHidden else { return }
        runDefaults(hide: true)
        isHidden = true
    }

    func show() {
        guard isHidden else { return }
        runDefaults(hide: false)
        isHidden = false
    }

    private func runDefaults(hide: Bool) {
        let value = hide ? "false" : "true"
        let defaults = Process()
        defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaults.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", value]
        try? defaults.run()
        defaults.waitUntilExit()

        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Finder"]
        try? killall.run()
    }

    @objc private func appWillTerminate() {
        if isHidden { show() }
    }
}
