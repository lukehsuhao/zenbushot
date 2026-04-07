import AppKit

protocol CanvasViewDelegate: AnyObject {
    func canvasDidRequestToolSwitch(_ toolType: ToolType)
}

class EditorWindowController: NSWindowController {
    private var canvasView: CanvasView!
    private var editorToolbar: EditorToolbar!
    private let result: CaptureResult
    private var currentColor: NSColor = Theme.Colors.defaultAnnotationColor
    private var currentStrokeWidth: CGFloat = UserSettings.shared.defaultStrokeWidth
    private var tools: [ToolType: Tool] = [:]

    private static var openEditors: [EditorWindowController] = []

    init(result: CaptureResult) {
        self.result = result

        let imageSize = result.image.size
        let maxW = Theme.Dimensions.editorMaxWidth
        let maxH = Theme.Dimensions.editorMaxHeight
        let scale = min(min(maxW, imageSize.width) / imageSize.width,
                        min(maxH, imageSize.height) / imageSize.height, 1.0)
        let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        let tbH = Theme.Dimensions.toolbarHeight
        let bbH = Theme.Dimensions.bottomBarHeight
        let windowWidth = max(displaySize.width, Theme.Dimensions.editorMinWidth)
        let windowSize = CGSize(width: windowWidth, height: displaySize.height + tbH + bbH)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("editor.title")
        window.center()
        window.minSize = NSSize(width: Theme.Dimensions.editorMinWidth, height: Theme.Dimensions.editorMinHeight)
        window.backgroundColor = Theme.Colors.surfacePrimary

        super.init(window: window)
        EditorWindowController.openEditors.append(self)
        window.delegate = self

        setupTools()
        setupUI(displaySize: displaySize)
        updateToolColor() // Apply default color and stroke from settings
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupTools() {
        tools[.selection] = SelectionTool()
        tools[.hand] = HandTool()
        tools[.arrow] = ArrowTool()
        tools[.line] = LineTool()
        tools[.rectangle] = RectangleTool()
        tools[.roundedRect] = RoundedRectangleTool()
        tools[.ellipse] = EllipseTool()
        tools[.freehand] = FreehandTool()
        tools[.text] = TextTool()
        tools[.counter] = CounterTool()
        tools[.highlighter] = HighlighterTool()
        tools[.blur] = BlurTool()
        tools[.mosaic] = MosaicTool()
        tools[.spotlight] = SpotlightTool()
    }

    private func setupUI(displaySize: CGSize) {
        guard let contentView = window?.contentView else { return }
        let tbH = Theme.Dimensions.toolbarHeight
        let bbH = Theme.Dimensions.bottomBarHeight

        // --- Toolbar ---
        editorToolbar = EditorToolbar(frame: CGRect(
            x: 0, y: contentView.bounds.height - tbH,
            width: contentView.bounds.width, height: tbH
        ))
        editorToolbar.autoresizingMask = [.width, .minYMargin]
        editorToolbar.delegate = self
        contentView.addSubview(editorToolbar)

        // --- Canvas ---
        let scrollView = NSScrollView(frame: CGRect(
            x: 0, y: bbH,
            width: contentView.bounds.width,
            height: contentView.bounds.height - tbH - bbH
        ))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.Colors.canvasBackground

        canvasView = CanvasView(
            frame: CGRect(origin: .zero, size: displaySize),
            image: result.image
        )
        canvasView.currentTool = tools[.selection]
        canvasView.canvasDelegate = self

        scrollView.documentView = canvasView
        contentView.addSubview(scrollView)

        // --- Bottom Bar ---
        let bottomBar = NSView(frame: CGRect(x: 0, y: 0, width: contentView.bounds.width, height: bbH))
        bottomBar.autoresizingMask = [.width]
        bottomBar.wantsLayer = true
        bottomBar.layer?.backgroundColor = Theme.Colors.surfacePrimary.cgColor

        // Top border on bottom bar
        let topBorder = NSView(frame: CGRect(x: 0, y: bbH - 1, width: contentView.bounds.width, height: 1))
        topBorder.wantsLayer = true
        topBorder.layer?.backgroundColor = Theme.Colors.separator.cgColor
        topBorder.autoresizingMask = [.width, .minYMargin]
        bottomBar.addSubview(topBorder)

        // Left: Undo / Redo
        let undoBtn = createBottomButton(title: L("editor.undo"), key: "z", modifiers: .command, action: #selector(performUndo))
        undoBtn.frame.origin = CGPoint(x: 12, y: 8)
        bottomBar.addSubview(undoBtn)

        let redoBtn = createBottomButton(title: L("editor.redo"), key: "z", modifiers: [.command, .shift], action: #selector(performRedo))
        redoBtn.frame.origin = CGPoint(x: 88, y: 8)
        bottomBar.addSubview(redoBtn)

        // Right: Copy / Save
        let saveBtn = createBottomButton(title: L("editor.save"), key: "s", modifiers: .command, action: #selector(saveImage))
        saveBtn.frame.origin = CGPoint(x: contentView.bounds.width - 82, y: 8)
        saveBtn.autoresizingMask = [.minXMargin]
        bottomBar.addSubview(saveBtn)

        let copyBtn = createBottomButton(title: L("editor.copy"), key: "c", modifiers: [.command, .shift], action: #selector(copyToClipboard))
        copyBtn.frame.origin = CGPoint(x: contentView.bounds.width - 164, y: 8)
        copyBtn.autoresizingMask = [.minXMargin]
        bottomBar.addSubview(copyBtn)

        // Center: Zoom controls
        let zoomOut = NSButton(frame: CGRect(x: 0, y: 8, width: 28, height: 28))
        zoomOut.image = NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Zoom Out")
        zoomOut.isBordered = false
        zoomOut.target = self
        zoomOut.action = #selector(zoomOutAction)
        bottomBar.addSubview(zoomOut)

        let zoomLabel = NSTextField(labelWithString: "100%")
        zoomLabel.frame = CGRect(x: 0, y: 12, width: 50, height: 18)
        zoomLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        zoomLabel.alignment = .center
        zoomLabel.tag = 300
        bottomBar.addSubview(zoomLabel)

        let zoomIn = NSButton(frame: CGRect(x: 0, y: 8, width: 28, height: 28))
        zoomIn.image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom In")
        zoomIn.isBordered = false
        zoomIn.target = self
        zoomIn.action = #selector(zoomInAction)
        bottomBar.addSubview(zoomIn)

        let zoomFit = NSButton(frame: CGRect(x: 0, y: 8, width: 28, height: 28))
        zoomFit.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Fit")
        zoomFit.isBordered = false
        zoomFit.target = self
        zoomFit.action = #selector(zoomFitAction)
        bottomBar.addSubview(zoomFit)

        // Position zoom controls centered
        let zoomTotalW: CGFloat = 28 + 50 + 28 + 28 + 8
        let zoomStartX = (contentView.bounds.width - zoomTotalW) / 2
        zoomOut.frame.origin.x = zoomStartX
        zoomLabel.frame.origin.x = zoomStartX + 28
        zoomIn.frame.origin.x = zoomStartX + 28 + 50
        zoomFit.frame.origin.x = zoomStartX + 28 + 50 + 28 + 4

        contentView.addSubview(bottomBar)

        // Listen for zoom changes
        canvasView.onZoomChanged = { [weak self] level in
            if let label = self?.window?.contentView?.viewWithTag(300) as? NSTextField {
                label.stringValue = "\(Int(level * 100))%"
            }
        }
    }

    private func createBottomButton(title: String, key: String, modifiers: NSEvent.ModifierFlags, action: Selector) -> NSButton {
        let btn = NSButton(frame: CGRect(x: 0, y: 0, width: 70, height: 28))
        btn.title = title
        btn.bezelStyle = .rounded
        btn.controlSize = .small
        btn.font = Theme.Fonts.toolbar
        btn.keyEquivalent = key
        btn.keyEquivalentModifierMask = modifiers
        btn.target = self
        btn.action = action
        return btn
    }

    @objc private func showBackgroundTool() {
        guard let bgBtn = window?.contentView?.subviews.last?.subviews.first(where: {
            ($0 as? NSButton)?.title == "Background"
        }) else { return }

        BackgroundConfigPanel.show(from: bgBtn) { [weak self] config in
            guard let self = self else { return }
            let original = self.canvasView.flattenedImage()
            let withBg = BackgroundConfigPanel.applyBackground(config, to: original)

            // Replace canvas with the new image
            self.canvasView.baseImage = withBg
            self.canvasView.frame = CGRect(origin: .zero, size: withBg.size)
            self.canvasView.needsDisplay = true
        }
    }

    @objc private func performUndo() { canvasView.undoManager?.undo() }
    @objc private func performRedo() { canvasView.undoManager?.redo() }

    @objc private func copyToClipboard() {
        ClipboardService.copyImage(canvasView.flattenedImage())
        window?.close()
    }

    @objc private func zoomInAction() { canvasView.zoomIn() }
    @objc private func zoomOutAction() { canvasView.zoomOut() }
    @objc private func zoomFitAction() { canvasView.zoomToFit() }

    @objc private func saveImage() {
        FileExportService.saveImage(canvasView.flattenedImage())
    }

    private func updateToolColor() {
        if let t = tools[.arrow] as? ArrowTool { t.color = currentColor; t.strokeWidth = currentStrokeWidth }
        if let t = tools[.line] as? LineTool { t.color = currentColor; t.strokeWidth = currentStrokeWidth }
        if let t = tools[.rectangle] as? RectangleTool { t.color = currentColor; t.strokeWidth = currentStrokeWidth }
        if let t = tools[.ellipse] as? EllipseTool { t.color = currentColor; t.strokeWidth = currentStrokeWidth }
        if let t = tools[.freehand] as? FreehandTool { t.color = currentColor; t.strokeWidth = currentStrokeWidth }
        if let t = tools[.text] as? TextTool { t.color = currentColor }
        if let t = tools[.counter] as? CounterTool { t.color = currentColor }
        if let t = tools[.highlighter] as? HighlighterTool { t.color = currentColor }
    }
}

// MARK: - EditorToolbarDelegate

extension EditorWindowController: EditorToolbarDelegate {
    func toolbarDidSelectTool(_ toolType: ToolType) {
        if let textTool = canvasView.currentTool as? TextTool { textTool.commitActiveText() }
        canvasView.currentTool = tools[toolType]
    }

    func toolbarDidChangeColor(_ color: NSColor) {
        currentColor = color
        updateToolColor()

        // Update selected annotation's border color
        if let selected = canvasView.selectionState.selectedAnnotation {
            selected.color = color
            canvasView.needsDisplay = true
        }
    }

    func toolbarDidChangeFillColor(_ color: NSColor) {
        if let tool = tools[.rectangle] as? RectangleTool { tool.fillColor = color }
        if let tool = tools[.roundedRect] as? RoundedRectangleTool { tool.fillColor = color }
        if let tool = tools[.ellipse] as? EllipseTool { tool.fillColor = color }

        // Update selected annotation's fill color
        if let selected = canvasView.selectionState.selectedAnnotation {
            if let rect = selected as? RectangleAnnotation { rect.fillColor = color }
            else if let rr = selected as? RoundedRectAnnotation { rr.fillColor = color }
            else if let ell = selected as? EllipseAnnotation { ell.fillColor = color }
            canvasView.needsDisplay = true
        }
    }

    func toolbarDidChangeStrokeWidth(_ width: CGFloat) {
        currentStrokeWidth = width
        updateToolColor()

        // Update selected annotation's stroke width
        if let selected = canvasView.selectionState.selectedAnnotation {
            selected.strokeWidth = width
            canvasView.needsDisplay = true
        }
    }
}

// MARK: - CanvasViewDelegate

extension EditorWindowController: CanvasViewDelegate {
    func canvasDidRequestToolSwitch(_ toolType: ToolType) {
        if let textTool = canvasView.currentTool as? TextTool { textTool.commitActiveText() }
        canvasView.currentTool = tools[toolType]
        editorToolbar.selectTool(toolType)
    }
}

// MARK: - NSWindowDelegate

extension EditorWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        EditorWindowController.openEditors.removeAll { $0 === self }
    }
}
