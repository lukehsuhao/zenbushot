import AppKit

class StatusBarController {
    static weak var current: StatusBarController?
    private var statusItem: NSStatusItem
    private weak var coordinator: CaptureCoordinator?

    init(coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "AnyShot")
        }

        setupMenu()
        StatusBarController.current = self
    }

    func rebuildMenu() {
        setupMenu()
    }

    private func makeItem(_ title: String, icon: String, action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = [.command, .shift]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        return item
    }

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(makeItem(L("menu.area"), icon: "rectangle.dashed", action: #selector(captureArea), key: "4"))
        menu.addItem(makeItem(L("menu.fullscreen"), icon: "desktopcomputer", action: #selector(captureFullscreen), key: "3"))
        menu.addItem(makeItem(L("menu.window"), icon: "macwindow", action: #selector(captureWindow), key: "5"))
        menu.addItem(makeItem(L("menu.scrolling"), icon: "rectangle.bottomhalf.inset.filled", action: #selector(scrollingCapture), key: "7"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem(L("menu.freeze"), icon: "snowflake", action: #selector(freezeCapture)))

        let timerItem = NSMenuItem(title: L("menu.selftimer"), action: nil, keyEquivalent: "")
        timerItem.image = NSImage(systemSymbolName: "timer", accessibilityDescription: L("menu.selftimer"))
        let timerMenu = NSMenu()
        for delay in [3, 5, 10] {
            let item = NSMenuItem(title: L("menu.seconds", delay), action: #selector(timedCapture(_:)), keyEquivalent: "")
            item.target = self; item.tag = delay
            item.image = NSImage(systemSymbolName: "\(delay).circle", accessibilityDescription: "\(delay)s")
            timerMenu.addItem(item)
        }
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem(L("menu.ocr"), icon: "text.viewfinder", action: #selector(captureOCR), key: "2"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem(L("menu.record.area"), icon: "record.circle", action: #selector(startAreaRecording), key: "8"))
        menu.addItem(makeItem(L("menu.record.fullscreen"), icon: "record.circle.fill", action: #selector(startFullRecording), key: "9"))

        menu.addItem(NSMenuItem.separator())

        let desktopItem = makeItem(L("menu.hide.desktop"), icon: "eye.slash", action: #selector(toggleDesktopIcons(_:)))
        desktopItem.keyEquivalent = ""
        menu.addItem(desktopItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem(L("menu.preferences"), icon: "gearshape", action: #selector(showPreferences), key: ",", modifiers: .command))
        menu.addItem(makeItem(L("menu.quit"), icon: "power", action: #selector(quit), key: "q", modifiers: .command))

        statusItem.menu = menu
    }

    @objc private func captureArea() { coordinator?.startCapture(mode: .area) }
    @objc private func captureWindow() { coordinator?.startCapture(mode: .window) }
    @objc private func captureFullscreen() { coordinator?.startCapture(mode: .fullscreen) }
    @objc private func capturePreviousArea() { coordinator?.startCapture(mode: .previousArea) }
    @objc private func scrollingCapture() { coordinator?.startCapture(mode: .scrollingCapture) }
    @objc private func freezeCapture() { coordinator?.startCapture(mode: .freezeArea) }
    @objc private func timedCapture(_ sender: NSMenuItem) { coordinator?.startCapture(mode: .timedFullscreen(delay: sender.tag)) }
    @objc private func captureOCR() { coordinator?.startCapture(mode: .ocr) }
    @objc private func startAreaRecording() { RecordingCoordinator.shared.startRecording(fullscreen: false) }
    @objc private func startFullRecording() { RecordingCoordinator.shared.startRecording(fullscreen: true) }
    @objc private func stopRecording() { RecordingCoordinator.shared.stopRecording() }
    @objc private func toggleDesktopIcons(_ sender: NSMenuItem) {
        DesktopIconHider.shared.toggle()
        sender.state = DesktopIconHider.shared.isHidden ? .on : .off
    }
    @objc private func showHistory() { CaptureHistoryWindowController.show() }
    @objc private func showPreferences() { PreferencesWindowController.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
