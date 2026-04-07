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
    private let dismissDelay = UserSettings.shared.previewDismissDelay

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
        layer?.cornerRadius = 12
        layer?.masksToBounds = true

        // Image fills the entire preview with rounded corners
        let imageView = NSImageView(frame: bounds)
        imageView.image = capturedImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 12
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        // Progress bar — thin line at very bottom, inside rounded corners
        progressBar = ProgressBarView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: 3))
        progressBar.autoresizingMask = [.width]
        addSubview(progressBar)

        // Circular buttons scattered around edges (hidden by default, shown on hover)
        buttonBar = NSView(frame: bounds)
        buttonBar.wantsLayer = true
        buttonBar.alphaValue = 0
        buttonBar.autoresizingMask = [.width, .height]

        let cs: CGFloat = 34  // circle size
        let ic: CGFloat = 17  // icon size
        let m: CGFloat = 8    // margin from edge
        let g: CGFloat = 4    // gap between stacked buttons
        let w = bounds.width
        let h = bounds.height

        // Layout: buttons at corners/edges
        // tag maps to: 0=copy, 1=quickSave, 2=edit, 3=ocr, 4=pin, 5=close
        // side: true=left, false=right (determines label position)
        let positions: [(icon: String, label: String, x: CGFloat, y: CGFloat, tag: Int, leftSide: Bool)] = [
            ("xmark",                      L("pin.close"),    m,            h - m - cs,                5, true),
            ("pin.fill",                   L("preview.pin"),  m,            h - m - cs - (cs + g),     4, true),
            ("text.viewfinder",            L("preview.ocr"),  m,            m,                          3, true),
            ("doc.on.clipboard",           L("preview.copy"), w - m - cs,   h - m - cs,                0, false),
            ("square.and.arrow.down.fill", L("preview.save"), w - m - cs,   h - m - cs - (cs + g),     1, false),
            ("square.and.pencil",          L("preview.edit"), w - m - cs,   m,                          2, false),
        ]

        for (icon, label, x, y, tag, leftSide) in positions {
            let circleBtn = PreviewCircleButton(
                frame: NSRect(x: x, y: y, width: cs, height: cs),
                icon: icon, label: label, iconSize: ic, leftSide: leftSide,
                tag: tag, target: self, action: #selector(buttonClicked(_:)),
                parentView: buttonBar
            )
            buttonBar.addSubview(circleBtn)
        }
        addSubview(buttonBar)

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
        // Only start drag from the image area (above the overlay bar)
        if location.y > 40 {
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

// MARK: - Circle Button with hover label

class PreviewCircleButton: NSView {
    weak var labelView: NSTextField?
    private var isButtonHovered = false

    init(frame: NSRect, icon: String, label: String, iconSize: CGFloat, leftSide: Bool,
         tag: Int, target: AnyObject, action: Selector, parentView: NSView) {
        super.init(frame: frame)

        wantsLayer = true
        layer?.cornerRadius = frame.width / 2
        layer?.backgroundColor = NSColor(white: 0.85, alpha: 0.9).cgColor

        let pad = (frame.width - iconSize) / 2
        let iconView = NSImageView(frame: NSRect(x: pad, y: pad, width: iconSize, height: iconSize))
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: label)
        iconView.contentTintColor = NSColor(white: 0.25, alpha: 1.0)
        addSubview(iconView)

        let btn = NSButton(frame: bounds)
        btn.isBordered = false
        btn.isTransparent = true
        btn.tag = tag
        btn.target = target
        btn.action = action
        addSubview(btn)

        // Label added to parent (not self) so it's not clipped
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let textWidth = (label as NSString).size(withAttributes: [.font: font]).width + 14
        let labelHeight: CGFloat = 20
        let labelX: CGFloat = leftSide ? frame.origin.x + frame.width + 6 : frame.origin.x - textWidth - 6
        let labelY: CGFloat = frame.origin.y + (frame.height - labelHeight) / 2

        let lbl = NSTextField(labelWithString: label)
        lbl.font = font
        lbl.textColor = .white
        lbl.backgroundColor = NSColor(white: 0.1, alpha: 0.85)
        lbl.isBezeled = false
        lbl.drawsBackground = true
        lbl.wantsLayer = true
        lbl.layer?.cornerRadius = 5
        lbl.alignment = .center
        lbl.frame = NSRect(x: labelX, y: labelY, width: textWidth, height: labelHeight)
        lbl.alphaValue = 0
        parentView.addSubview(lbl)
        self.labelView = lbl

        // Tracking area
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil
        ))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) {
        isButtonHovered = true
        NSCursor.pointingHand.push()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            labelView?.animator().alphaValue = 1
        }
    }

    override func mouseExited(with event: NSEvent) {
        isButtonHovered = false
        NSCursor.pop()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            labelView?.animator().alphaValue = 0
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
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
