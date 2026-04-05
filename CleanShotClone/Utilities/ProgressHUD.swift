import AppKit

class ProgressHUD {
    private static var currentPanel: NSPanel?

    static func show(message: String) {
        dismiss()

        guard let screen = NSScreen.main else { return }

        let panelWidth: CGFloat = 200
        let panelHeight: CGFloat = 80

        let panelFrame = CGRect(
            x: screen.frame.midX - panelWidth / 2,
            y: screen.frame.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let contentView = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelFrame.size))
        contentView.material = .hudWindow
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12

        // Spinner
        let spinner = NSProgressIndicator(frame: NSRect(x: (panelWidth - 32) / 2, y: 36, width: 32, height: 32))
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.startAnimation(nil)
        contentView.addSubview(spinner)

        // Label
        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 0, y: 8, width: panelWidth, height: 20)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .labelColor
        contentView.addSubview(label)

        panel.contentView = contentView
        panel.makeKeyAndOrderFront(nil)

        currentPanel = panel
    }

    static func dismiss() {
        currentPanel?.orderOut(nil)
        currentPanel = nil
    }
}
