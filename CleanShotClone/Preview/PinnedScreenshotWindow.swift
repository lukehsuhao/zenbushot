import AppKit

class PinnedScreenshotWindow {
    private static var pinnedWindows: [NSPanel] = []

    static func pin(image: NSImage) {
        let imageSize = image.size

        guard let screen = NSScreen.main else { return }

        // Use the actual image size, but cap to screen dimensions with some margin
        let maxW = screen.visibleFrame.width * 0.9
        let maxH = screen.visibleFrame.height * 0.9
        let scale = min(maxW / imageSize.width, maxH / imageSize.height, 1.0)
        let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        // Position at center of screen
        let panelFrame = CGRect(
            x: screen.frame.midX - displaySize.width / 2,
            y: screen.frame.midY - displaySize.height / 2,
            width: displaySize.width,
            height: displaySize.height
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = L("pin.title")
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        panel.isOpaque = true
        panel.aspectRatio = displaySize

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: displaySize))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]

        panel.contentView = imageView

        // Context menu
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: L("pin.copy"), action: #selector(PinnedAction.copyImage(_:)), keyEquivalent: "c")
        let saveItem = NSMenuItem(title: L("pin.save"), action: #selector(PinnedAction.saveImage(_:)), keyEquivalent: "s")
        let closeItem = NSMenuItem(title: L("pin.close"), action: #selector(PinnedAction.closePin(_:)), keyEquivalent: "w")

        let action = PinnedAction(image: image, panel: panel)
        copyItem.target = action
        saveItem.target = action
        closeItem.target = action

        menu.addItem(copyItem)
        menu.addItem(saveItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(closeItem)

        imageView.menu = menu

        // Store action to prevent deallocation
        objc_setAssociatedObject(panel, "pinnedAction", action, .OBJC_ASSOCIATION_RETAIN)

        panel.makeKeyAndOrderFront(nil)
        pinnedWindows.append(panel)
    }
}

class PinnedAction: NSObject {
    let image: NSImage
    weak var panel: NSPanel?

    init(image: NSImage, panel: NSPanel) {
        self.image = image
        self.panel = panel
    }

    @objc func copyImage(_ sender: Any) {
        ClipboardService.copyImage(image)
    }

    @objc func saveImage(_ sender: Any) {
        FileExportService.saveImage(image)
    }

    @objc func closePin(_ sender: Any) {
        panel?.orderOut(nil)
    }
}
