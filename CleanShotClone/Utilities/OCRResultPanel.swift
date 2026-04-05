import AppKit

class OCRResultPanel {
    private static var currentPanel: NSPanel?

    static func show(text: String) {
        dismiss()

        guard let screen = NSScreen.main else { return }

        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 280

        let panelFrame = CGRect(
            x: screen.frame.midX - panelWidth / 2,
            y: screen.frame.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Text Copied (\(text.count) characters)"
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true

        let contentView = NSView(frame: NSRect(origin: .zero, size: panelFrame.size))

        // Scrollable text view showing the copied text
        let scrollView = NSScrollView(frame: NSRect(x: 12, y: 50, width: panelWidth - 24, height: panelHeight - 80))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: scrollView.bounds)
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width, .height]
        scrollView.documentView = textView
        contentView.addSubview(scrollView)

        // Bottom bar with buttons
        let closeBtn = NSButton(title: "Close", target: OCRResultAction.shared, action: #selector(OCRResultAction.closePanel))
        closeBtn.frame = CGRect(x: panelWidth - 90, y: 12, width: 78, height: 28)
        closeBtn.setButtonType(.momentaryPushIn)
        closeBtn.bezelStyle = .rounded
        closeBtn.keyEquivalent = "\u{1b}"
        contentView.addSubview(closeBtn)

        let copyBtn = NSButton(title: "Copy Again", target: OCRResultAction.shared, action: #selector(OCRResultAction.copyAgain))
        copyBtn.frame = CGRect(x: panelWidth - 190, y: 12, width: 92, height: 28)
        copyBtn.setButtonType(.momentaryPushIn)
        copyBtn.bezelStyle = .rounded
        contentView.addSubview(copyBtn)

        panel.contentView = contentView

        OCRResultAction.shared.text = text
        OCRResultAction.shared.panel = panel

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        currentPanel = panel
    }

    static func dismiss() {
        currentPanel?.orderOut(nil)
        currentPanel = nil
    }
}

class OCRResultAction: NSObject {
    static let shared = OCRResultAction()
    var text: String = ""
    weak var panel: NSPanel?

    @objc func closePanel() {
        panel?.orderOut(nil)
    }

    @objc func copyAgain() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        panel?.title = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }
}
