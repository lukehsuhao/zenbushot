import AppKit

class OCRResultWindow {
    private static var currentPanel: NSPanel?

    static func show(text: String, sourceImage: NSImage) {
        currentPanel?.orderOut(nil)

        let panelWidth: CGFloat = 560
        let panelHeight: CGFloat = 500

        guard let screen = NSScreen.main else { return }
        let panelFrame = CGRect(
            x: screen.frame.midX - panelWidth / 2,
            y: screen.frame.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "OCR Result"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.minSize = NSSize(width: 400, height: 300)

        let contentView = NSView(frame: NSRect(origin: .zero, size: panelFrame.size))

        // Source image preview at top
        let imageHeight: CGFloat = 150
        let imageView = NSImageView(frame: NSRect(x: 12, y: panelHeight - imageHeight - 12, width: panelWidth - 24, height: imageHeight))
        imageView.image = sourceImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .minYMargin]
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.borderWidth = 1
        imageView.layer?.borderColor = NSColor.separatorColor.cgColor
        contentView.addSubview(imageView)

        // Image info label
        let imgInfo = NSTextField(labelWithString: "Captured: \(Int(sourceImage.size.width))×\(Int(sourceImage.size.height)) px")
        imgInfo.frame = NSRect(x: 12, y: panelHeight - imageHeight - 30, width: 300, height: 14)
        imgInfo.font = NSFont.systemFont(ofSize: 10)
        imgInfo.textColor = .tertiaryLabelColor
        imgInfo.autoresizingMask = [.minYMargin]
        contentView.addSubview(imgInfo)

        // Text view with scroll
        let textTop = panelHeight - imageHeight - 48
        let scrollView = NSScrollView(frame: NSRect(
            x: 12, y: 52,
            width: panelWidth - 24,
            height: textTop - 52
        ))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.string = text
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width, .height]

        scrollView.documentView = textView
        contentView.addSubview(scrollView)

        // Copy button
        let copyBtn = NSButton(frame: NSRect(x: panelWidth - 112, y: 12, width: 100, height: 28))
        copyBtn.title = "Copy All"
        copyBtn.bezelStyle = .rounded
        copyBtn.autoresizingMask = [.minXMargin]

        let copyAction = CopyAction(text: text)
        copyBtn.target = copyAction
        copyBtn.action = #selector(CopyAction.copyText)
        objc_setAssociatedObject(panel, "copyAction", copyAction, .OBJC_ASSOCIATION_RETAIN)
        contentView.addSubview(copyBtn)

        // Character count label
        let countLabel = NSTextField(labelWithString: "\(text.count) characters")
        countLabel.frame = NSRect(x: 12, y: 16, width: 200, height: 20)
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.autoresizingMask = [.maxXMargin]
        contentView.addSubview(countLabel)

        panel.contentView = contentView
        panel.makeKeyAndOrderFront(nil)
        currentPanel = panel
    }
}

class OCRClickView: NSView {
    var onClick: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onClick?() }
}

class CopyAction: NSObject {
    let text: String
    init(text: String) { self.text = text }

    @objc func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
