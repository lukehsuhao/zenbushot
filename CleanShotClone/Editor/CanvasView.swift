import AppKit

class CanvasView: NSView, NSTextFieldDelegate {
    var baseImage: NSImage
    private(set) var annotations: [Annotation] = []
    let selectionState = SelectionState()
    weak var canvasDelegate: CanvasViewDelegate?
    private var hoveredAnnotation: Annotation?
    private var mouseTrackingArea: NSTrackingArea?
    private var originalSize: CGSize = .zero
    private(set) var zoomLevel: CGFloat = 1.0
    var onZoomChanged: ((CGFloat) -> Void)?

    var currentTool: Tool? {
        didSet { resetCursorRects() }
    }

    init(frame: NSRect, image: NSImage) {
        self.baseImage = image
        self.originalSize = frame.size
        super.init(frame: frame)
        wantsLayer = true
        setupMouseTracking()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupMouseTracking() {
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        mouseTrackingArea = area
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Base image
        if let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: bounds)
        }

        // Blur/Mosaic (reads base image)
        for ann in annotations {
            if let blur = ann as? BlurAnnotation { blur.renderBlur(baseImage: baseImage, in: context) }
            else if let mosaic = ann as? MosaicAnnotation { mosaic.renderMosaic(baseImage: baseImage, in: context, canvasSize: bounds.size) }
        }

        // Spotlight (full-canvas effect)
        for ann in annotations where ann is SpotlightAnnotation {
            ann.render(in: context, canvasSize: bounds.size)
        }

        // Other annotations
        for ann in annotations {
            if !(ann is BlurAnnotation) && !(ann is MosaicAnnotation) && !(ann is SpotlightAnnotation) {
                ann.render(in: context, canvasSize: bounds.size)
            }
        }

        // Hover highlight (thin outline on hoverable annotations)
        if let hovered = hoveredAnnotation,
           hovered.id != selectionState.selectedAnnotation?.id,
           currentTool is SelectionTool {
            context.setStrokeColor(Theme.Colors.accentBlue.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [3, 3])
            context.stroke(hovered.boundingRect.insetBy(dx: -2, dy: -2))
            context.setLineDash(phase: 0, lengths: [])
        }

        // Selection handles
        if let selected = selectionState.selectedAnnotation {
            drawSelectionHandles(for: selected, in: context)
        }
    }

    private func drawSelectionHandles(for annotation: Annotation, in context: CGContext) {
        let rect = annotation.boundingRect
        let handleSize = Theme.Dimensions.handleSize

        // Dashed border
        context.setStrokeColor(Theme.Colors.accentBlue.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.stroke(rect)
        context.setLineDash(phase: 0, lengths: [])

        // Handles
        for handle in HandlePosition.allCases {
            let point = handle.point(in: rect)
            let handleRect = CGRect(
                x: point.x - handleSize / 2,
                y: point.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            context.setFillColor(NSColor.white.cgColor)
            context.fill(handleRect)
            context.setStrokeColor(Theme.Colors.accentBlue.cgColor)
            context.setLineWidth(1.5)
            context.stroke(handleRect)
        }
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        discardCursorRects()
        if let cursor = currentTool?.cursor() {
            addCursorRect(bounds, cursor: cursor)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        currentTool?.mouseDown(at: point, in: self)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentTool?.mouseDragged(to: point, in: self)
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentTool?.mouseUp(at: point, in: self)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Update hover state for selection tool
        if currentTool is SelectionTool {
            // Check resize handles first
            if selectionState.isSelected {
                if let handle = selectionState.handleAt(point) {
                    NSCursor.pop()
                    selectionState.cursorForHandle(handle).push()
                    return
                }
            }

            // Check annotation hover
            var newHovered: Annotation?
            for ann in annotations.reversed() {
                if ann.hitTest(point) {
                    newHovered = ann
                    break
                }
            }

            if newHovered?.id != hoveredAnnotation?.id {
                hoveredAnnotation = newHovered
                needsDisplay = true
            }

            // Update cursor
            NSCursor.pop()
            if hoveredAnnotation != nil {
                NSCursor.openHand.push()
            } else {
                NSCursor.arrow.push()
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Zoom

    func setZoom(_ level: CGFloat) {
        zoomLevel = min(max(level, 0.25), 5.0)
        let newSize = CGSize(width: originalSize.width * zoomLevel, height: originalSize.height * zoomLevel)
        setFrameSize(newSize)
        needsDisplay = true
        onZoomChanged?(zoomLevel)
    }

    /// Zoom centered on a specific point in the canvas
    func setZoom(_ level: CGFloat, centeredOn point: CGPoint) {
        guard let scrollView = enclosingScrollView else {
            setZoom(level)
            return
        }

        let oldZoom = zoomLevel
        let newZoom = min(max(level, 0.25), 5.0)
        guard newZoom != oldZoom else { return }

        // Point in canvas coordinates before zoom
        let visibleRect = scrollView.contentView.bounds

        // Where the mouse is relative to the visible area
        let mouseInVisible = CGPoint(
            x: point.x - visibleRect.origin.x,
            y: point.y - visibleRect.origin.y
        )

        // Apply zoom
        zoomLevel = newZoom
        let newSize = CGSize(width: originalSize.width * zoomLevel, height: originalSize.height * zoomLevel)
        setFrameSize(newSize)
        needsDisplay = true
        onZoomChanged?(zoomLevel)

        // Calculate new scroll position to keep mouse point stable
        let scale = newZoom / oldZoom
        let newOrigin = CGPoint(
            x: point.x * scale - mouseInVisible.x,
            y: point.y * scale - mouseInVisible.y
        )
        scrollView.contentView.scroll(to: newOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func zoomIn() { setZoom(zoomLevel * 1.25) }
    func zoomOut() { setZoom(zoomLevel / 1.25) }
    func zoomToFit() { setZoom(1.0) }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let mousePoint = convert(event.locationInWindow, from: nil)
            let delta = event.scrollingDeltaY
            if delta > 0 {
                setZoom(zoomLevel * 1.1, centeredOn: mousePoint)
            } else if delta < 0 {
                setZoom(zoomLevel / 1.1, centeredOn: mousePoint)
            }
        } else {
            super.scrollWheel(with: event)
        }
    }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        let hasCmd = event.modifierFlags.contains(.command)
        let hasShift = event.modifierFlags.contains(.shift)

        // Tool shortcuts (only when not Cmd-modified)
        if !hasCmd {
            if let toolType = toolTypeForKey(event.charactersIgnoringModifiers ?? "") {
                canvasDelegate?.canvasDidRequestToolSwitch(toolType)
                return
            }
        }

        switch keyCode {
        case 51, 117: // Delete, Forward Delete
            deleteSelectedAnnotation()
        case 53: // Escape
            selectionState.clear()
            needsDisplay = true
        case 123: // Left
            nudgeSelected(dx: hasShift ? -10 : -1, dy: 0)
        case 124: // Right
            nudgeSelected(dx: hasShift ? 10 : 1, dy: 0)
        case 125: // Down
            nudgeSelected(dx: 0, dy: hasShift ? -10 : -1)
        case 126: // Up
            nudgeSelected(dx: 0, dy: hasShift ? 10 : 1)
        case 2: // D
            if hasCmd { duplicateSelected() }
            else { super.keyDown(with: event) }
        default:
            super.keyDown(with: event)
        }
    }

    private func toolTypeForKey(_ key: String) -> ToolType? {
        switch key.lowercased() {
        case "v": return .selection
        case "a": return .arrow
        case "l": return .line
        case "r": return .rectangle
        case "u": return .roundedRect
        case "o": return .ellipse
        case "p": return .freehand
        case "t": return .text
        case "n": return .counter
        case "h": return .hand
        case "b": return .blur
        case "m": return .mosaic
        case "s": return .spotlight
        default: return nil
        }
    }

    private func deleteSelectedAnnotation() {
        guard let annotation = selectionState.selectedAnnotation else { return }
        let idx = annotations.firstIndex { $0.id == annotation.id }
        removeAnnotation(annotation)
        selectionState.clear()
        undoManager?.registerUndo(withTarget: self) { target in
            if let idx = idx {
                target.annotations.insert(annotation, at: min(idx, target.annotations.count))
            } else {
                target.annotations.append(annotation)
            }
            target.needsDisplay = true
        }
    }

    private func nudgeSelected(dx: CGFloat, dy: CGFloat) {
        guard let annotation = selectionState.selectedAnnotation else { return }
        let origRect = annotation.boundingRect

        if let arrow = annotation as? ArrowAnnotation {
            let os = arrow.startPoint, oe = arrow.endPoint
            arrow.startPoint.x += dx; arrow.startPoint.y += dy
            arrow.endPoint.x += dx; arrow.endPoint.y += dy
            registerMoveUndo(annotation: annotation, previousRect: origRect, previousStart: os, previousEnd: oe)
        } else if let line = annotation as? LineAnnotation {
            let os = line.startPoint, oe = line.endPoint
            line.startPoint.x += dx; line.startPoint.y += dy
            line.endPoint.x += dx; line.endPoint.y += dy
            registerMoveUndo(annotation: annotation, previousRect: origRect, previousStart: os, previousEnd: oe)
        } else {
            annotation.move(by: CGSize(width: dx, height: dy))
            registerMoveUndo(annotation: annotation, previousRect: origRect)
        }
        needsDisplay = true
    }

    private func duplicateSelected() {
        guard let annotation = selectionState.selectedAnnotation else { return }
        let dup = annotation.copy()
        dup.move(by: CGSize(width: 20, height: -20))
        addAnnotation(dup)
        registerUndo(annotation: dup)
        selectionState.selectedAnnotation = dup
        needsDisplay = true
    }

    // MARK: - Text Editing

    func startEditingText(_ annotation: TextAnnotation) {
        removeAnnotation(annotation)
        selectionState.clear()

        let tf = NSTextField(frame: CGRect(
            x: annotation.boundingRect.origin.x,
            y: annotation.boundingRect.origin.y,
            width: max(annotation.boundingRect.width, 100),
            height: max(annotation.boundingRect.height, 28)
        ))
        tf.font = NSFont.systemFont(ofSize: annotation.fontSize, weight: .medium)
        tf.textColor = annotation.color
        tf.stringValue = annotation.text
        tf.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        tf.isBezeled = false
        tf.isEditable = true
        tf.focusRingType = .none
        tf.tag = 999

        addSubview(tf)
        window?.makeFirstResponder(tf)
        objc_setAssociatedObject(tf, "originalAnnotation", annotation, .OBJC_ASSOCIATION_RETAIN)
    }

    // MARK: - Annotation Management

    func addAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
        needsDisplay = true
    }

    func removeAnnotation(_ annotation: Annotation) {
        annotations.removeAll { $0.id == annotation.id }
        needsDisplay = true
    }

    func registerUndo(annotation: Annotation) {
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeAnnotation(annotation)
            target.undoManager?.registerUndo(withTarget: target) { t2 in t2.addAnnotation(annotation) }
        }

        // Auto-select the newly created annotation
        selectionState.selectedAnnotation = annotation
        needsDisplay = true
    }

    func registerMoveUndo(annotation: Annotation, previousRect: CGRect,
                          previousStart: CGPoint? = nil, previousEnd: CGPoint? = nil) {
        let curRect = annotation.boundingRect
        let curStart = (annotation as? ArrowAnnotation)?.startPoint ?? (annotation as? LineAnnotation)?.startPoint
        let curEnd = (annotation as? ArrowAnnotation)?.endPoint ?? (annotation as? LineAnnotation)?.endPoint

        undoManager?.registerUndo(withTarget: self) { target in
            if let arrow = annotation as? ArrowAnnotation, let ps = previousStart, let pe = previousEnd {
                arrow.startPoint = ps; arrow.endPoint = pe
            } else if let line = annotation as? LineAnnotation, let ps = previousStart, let pe = previousEnd {
                line.startPoint = ps; line.endPoint = pe
            } else {
                annotation.boundingRect = previousRect
            }
            if let b = annotation as? BlurAnnotation { b.invalidateCache() }
            if let m = annotation as? MosaicAnnotation { m.invalidateCache() }
            target.needsDisplay = true

            target.undoManager?.registerUndo(withTarget: target) { t2 in
                if let arrow = annotation as? ArrowAnnotation, let cs = curStart, let ce = curEnd {
                    arrow.startPoint = cs; arrow.endPoint = ce
                } else if let line = annotation as? LineAnnotation, let cs = curStart, let ce = curEnd {
                    line.startPoint = cs; line.endPoint = ce
                } else {
                    annotation.boundingRect = curRect
                }
                if let b = annotation as? BlurAnnotation { b.invalidateCache() }
                if let m = annotation as? MosaicAnnotation { m.invalidateCache() }
                t2.needsDisplay = true
            }
        }
    }

    // MARK: - Export

    func flattenedImage() -> NSImage {
        let size = baseImage.size
        let image = NSImage(size: size)
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return baseImage }

        if let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }

        for ann in annotations {
            if let blur = ann as? BlurAnnotation { blur.renderBlur(baseImage: baseImage, in: context) }
            else if let mosaic = ann as? MosaicAnnotation { mosaic.renderMosaic(baseImage: baseImage, in: context, canvasSize: bounds.size) }
        }
        for ann in annotations where ann is SpotlightAnnotation { ann.render(in: context, canvasSize: size) }
        for ann in annotations {
            if !(ann is BlurAnnotation) && !(ann is MosaicAnnotation) && !(ann is SpotlightAnnotation) {
                ann.render(in: context, canvasSize: size)
            }
        }

        image.unlockFocus()
        return image
    }

    func controlTextDidEndEditing(_ obj: Notification) {}
}
