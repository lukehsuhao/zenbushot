import AppKit

enum PreviewAction {
    case copy
    case save
    case quickSave
    case edit
    case ocr
    case pin
    case close
}

class FloatingPreviewWindow {
    private var panel: NSPanel?
    private var dismissTimer: Timer?
    private var timerStartDate: Date?
    private let result: CaptureResult
    private let actionHandler: (PreviewAction) -> Void
    private let dismissDelay = Theme.Dimensions.previewDismissDelay

    init(result: CaptureResult, actionHandler: @escaping (PreviewAction) -> Void) {
        self.result = result
        self.actionHandler = actionHandler
    }

    func show() {
        guard let screen = NSScreen.main else { return }

        let pw = Theme.Dimensions.previewWidth
        let ph = Theme.Dimensions.previewHeight
        let margin = Theme.Dimensions.previewMargin

        // Bottom-LEFT position (like CleanShot X)
        let panelFrame = CGRect(
            x: screen.visibleFrame.minX + margin,
            y: screen.visibleFrame.minY + margin,
            width: pw,
            height: ph
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let contentView = PreviewContentView(
            frame: NSRect(origin: .zero, size: panelFrame.size),
            image: result.image,
            actionHandler: actionHandler,
            previewWindow: self
        )
        panel.contentView = contentView

        // Slide-in from LEFT
        var startFrame = panelFrame
        startFrame.origin.x -= pw + margin
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Theme.Animation.slideIn
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(panelFrame, display: true)
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        startDismissTimer()
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let panel = panel else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Theme.Animation.fadeOut
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
        self.panel = nil
    }

    private func startDismissTimer() {
        dismissTimer?.invalidate()
        timerStartDate = Date()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissDelay, repeats: false) { [weak self] _ in
            // Notify coordinator via actionHandler so state resets properly
            self?.actionHandler(.close)
        }
    }

    func pauseTimer() {
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    func resumeTimer() {
        // Resume with remaining time
        guard let startDate = timerStartDate else { startDismissTimer(); return }
        let elapsed = Date().timeIntervalSince(startDate)
        let remaining = max(dismissDelay - elapsed, 1)
        dismissTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.actionHandler(.close)
        }
    }

    var timeRemainingFraction: CGFloat {
        guard let startDate = timerStartDate else { return 1 }
        let elapsed = Date().timeIntervalSince(startDate)
        return max(0, 1 - CGFloat(elapsed / dismissDelay))
    }
}

// MARK: - Preview Content View

class PreviewContentView: NSView, NSDraggingSource {
    private let actionHandler: (PreviewAction) -> Void
    private weak var previewWindow: FloatingPreviewWindow?
    private var capturedImage: NSImage
    private var buttonBar: NSView!
    private var progressBar: ProgressBarView!
    private var isHovered = false
    private var progressTimer: Timer?

    init(frame: NSRect, image: NSImage, actionHandler: @escaping (PreviewAction) -> Void, previewWindow: FloatingPreviewWindow) {
        self.actionHandler = actionHandler
        self.previewWindow = previewWindow
        self.capturedImage = image
        super.init(frame: frame)
        setupUI()
        setupTracking()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupTracking() {
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = Theme.Dimensions.previewCornerRadius
        layer?.masksToBounds = true
        layer?.backgroundColor = Theme.Colors.surfacePrimary.cgColor

        // Image view (fills most of the space)
        let imageView = NSImageView(frame: NSRect(x: 6, y: 48, width: bounds.width - 12, height: bounds.height - 54))
        imageView.image = capturedImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        // Button bar (hidden by default, revealed on hover)
        buttonBar = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: 42))
        buttonBar.wantsLayer = true
        buttonBar.alphaValue = 0 // Hidden by default
        buttonBar.autoresizingMask = [.width]

        let buttons: [(String, String, PreviewAction)] = [
            ("doc.on.clipboard", L("preview.copy"), .copy),
            ("square.and.arrow.down.fill", L("preview.save"), .quickSave),
            ("pencil.tip.crop.circle", L("preview.edit"), .edit),
            ("text.viewfinder", L("preview.ocr"), .ocr),
            ("pin.fill", L("preview.pin"), .pin),
            ("xmark.circle", "", .close),
        ]

        let padding: CGFloat = 4
        let btnW: CGFloat = (bounds.width - padding * 2) / CGFloat(buttons.count)
        for (i, (icon, title, _)) in buttons.enumerated() {
            let tintColor = i == buttons.count - 1
                ? NSColor.secondaryLabelColor
                : NSColor.labelColor

            let container = NSView(frame: NSRect(x: padding + CGFloat(i) * btnW, y: 4, width: btnW, height: 34))

            // Icon + label laid out as a centered pair
            let iconSize: CGFloat = 14
            let gap: CGFloat = title.isEmpty ? 0 : 3
            let font = NSFont.systemFont(ofSize: 11, weight: .medium)
            let textWidth = title.isEmpty ? 0 : (title as NSString).size(withAttributes: [.font: font]).width
            let totalW = iconSize + gap + textWidth
            let startX = (btnW - totalW) / 2

            let iconView = NSImageView(frame: NSRect(x: startX, y: (34 - iconSize) / 2, width: iconSize, height: iconSize))
            iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
            iconView.contentTintColor = tintColor
            container.addSubview(iconView)

            if !title.isEmpty {
                let label = NSTextField(labelWithString: title)
                label.font = font
                label.textColor = tintColor
                label.frame = NSRect(x: startX + iconSize + gap, y: (34 - 14) / 2, width: textWidth + 2, height: 14)
                container.addSubview(label)
            }

            // Invisible button on top for click handling
            let btn = NSButton(frame: NSRect(x: 0, y: 0, width: btnW, height: 34))
            btn.isBordered = false
            btn.isTransparent = true
            btn.tag = i
            btn.target = self
            btn.action = #selector(buttonClicked(_:))
            container.addSubview(btn)

            buttonBar.addSubview(container)
        }
        addSubview(buttonBar)

        // Progress bar at bottom
        progressBar = ProgressBarView(frame: NSRect(x: 0, y: 42, width: bounds.width, height: 3))
        progressBar.autoresizingMask = [.width]
        addSubview(progressBar)

        // Start progress animation
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let pw = self.previewWindow else { return }
            self.progressBar.progress = pw.timeRemainingFraction
            self.progressBar.needsDisplay = true
        }
    }

    @objc private func buttonClicked(_ sender: NSButton) {
        let actions: [PreviewAction] = [.copy, .quickSave, .edit, .ocr, .pin, .close]
        if sender.tag < actions.count { actionHandler(actions[sender.tag]) }
    }

    // MARK: - Hover

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        previewWindow?.pauseTimer()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Theme.Animation.buttonBarReveal
            buttonBar.animator().alphaValue = 1
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        previewWindow?.resumeTimer()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Theme.Animation.buttonBarReveal
            buttonBar.animator().alphaValue = 0
        }
    }

    // MARK: - Drag & Drop Source

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        // Only start drag from the image area (above button bar)
        if location.y > 48 {
            let draggingItem = NSDraggingItem(pasteboardWriter: capturedImage)
            draggingItem.setDraggingFrame(bounds, contents: capturedImage)
            beginDraggingSession(with: [draggingItem], event: event, source: self)
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            // Item was accepted by another app - auto dismiss
            actionHandler(.close)
        }
    }

    deinit {
        progressTimer?.invalidate()
    }
}

// MARK: - Progress Bar View

class ProgressBarView: NSView {
    var progress: CGFloat = 1.0

    override func draw(_ dirtyRect: NSRect) {
        let barWidth = bounds.width * progress
        Theme.Colors.accentBlue.withAlphaComponent(0.6).setFill()
        NSRect(x: 0, y: 0, width: barWidth, height: bounds.height).fill()
    }
}
