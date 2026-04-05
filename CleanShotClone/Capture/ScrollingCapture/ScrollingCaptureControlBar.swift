import AppKit

class ScrollingCaptureControlBar {
    private var panel: NSPanel?
    private var frameCountLabel: NSTextField?
    private var startBtn: NSButton?
    private var autoBtn: NSButton?
    private var doneBtn: NSButton?

    var onStart: (() -> Void)?
    var onAutoScroll: (() -> Void)?
    var onDone: (() -> Void)?
    var onCancel: (() -> Void)?

    func show(above rect: CGRect, screen: NSScreen) {
        let barWidth: CGFloat = 320
        let barHeight: CGFloat = 44

        // Position above the selection rect
        let screenFrame = screen.frame
        let x = rect.origin.x + screenFrame.origin.x + (rect.width - barWidth) / 2
        let y = rect.origin.y + screenFrame.origin.y + rect.height + 12

        let frame = CGRect(x: max(x, screenFrame.origin.x + 10), y: min(y, screenFrame.maxY - barHeight - 10), width: barWidth, height: barHeight)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        bg.material = .popover
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = barHeight / 2

        // Start button
        let start = makeButton(icon: "play.fill", title: L("scroll.start"), x: 16)
        start.target = self
        start.action = #selector(startClicked)
        start.contentTintColor = .systemGreen
        bg.addSubview(start)
        startBtn = start

        // Auto-Scroll button
        let auto = makeButton(icon: "arrow.down.circle.fill", title: L("scroll.auto"), x: 110)
        auto.target = self
        auto.action = #selector(autoClicked)
        bg.addSubview(auto)
        autoBtn = auto

        // Cancel button
        let cancel = makeButton(icon: "xmark.circle", title: "", x: barWidth - 44)
        cancel.frame.size.width = 32
        cancel.target = self
        cancel.action = #selector(cancelClicked)
        cancel.contentTintColor = .secondaryLabelColor
        bg.addSubview(cancel)

        panel.contentView = bg
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func showCapturingMode(frameCount: Int) {
        startBtn?.isHidden = true
        autoBtn?.isHidden = true

        guard let bg = panel?.contentView else { return }

        // Frame counter
        let label = NSTextField(labelWithString: L("scroll.frames", frameCount))
        label.frame = NSRect(x: 16, y: 12, width: 100, height: 20)
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        bg.addSubview(label)
        frameCountLabel = label

        // Done button
        let done = makeButton(icon: "checkmark.circle.fill", title: L("scroll.done"), x: 180)
        done.target = self
        done.action = #selector(doneClicked)
        done.contentTintColor = .systemGreen
        bg.addSubview(done)
        doneBtn = done
    }

    func updateFrameCount(_ count: Int) {
        frameCountLabel?.stringValue = L("scroll.frames", count)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func makeButton(icon: String, title: String, x: CGFloat) -> NSButton {
        let btn = NSButton(frame: NSRect(x: x, y: 6, width: 80, height: 32))
        btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        btn.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        btn.title = title
        btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        btn.isBordered = false
        btn.bezelStyle = .inline
        btn.contentTintColor = .labelColor
        // Tighten gap between icon and title
        if !title.isEmpty {
            btn.imageHugsTitle = true
            // Add a small space before the title for breathing room
            btn.attributedTitle = NSAttributedString(string: " \(title)", attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium)
            ])
        }
        return btn
    }

    @objc private func startClicked() { onStart?() }
    @objc private func autoClicked() { onAutoScroll?() }
    @objc private func doneClicked() { onDone?() }
    @objc private func cancelClicked() { onCancel?() }
}
