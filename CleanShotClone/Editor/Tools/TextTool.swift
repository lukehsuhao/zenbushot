import AppKit

class TextTool: Tool {
    let toolType: ToolType = .text
    var color: NSColor = .systemRed
    var fontSize: CGFloat = 18
    private weak var activeTextField: NSTextField?
    private weak var activeBorder: DashedBorderView?
    private weak var activeCanvas: CanvasView?

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        commitActiveText()

        activeCanvas = canvas

        let fieldWidth: CGFloat = 220
        let fieldHeight: CGFloat = 28
        let fieldFrame = CGRect(x: point.x, y: point.y - 12, width: fieldWidth, height: fieldHeight)

        // Dashed border around the text field
        let borderPadding: CGFloat = 4
        let borderFrame = CGRect(
            x: fieldFrame.origin.x - borderPadding,
            y: fieldFrame.origin.y - borderPadding,
            width: fieldFrame.width + borderPadding * 2,
            height: fieldFrame.height + borderPadding * 2
        )
        let border = DashedBorderView(frame: borderFrame)
        canvas.addSubview(border)
        activeBorder = border

        // Text field
        let textField = NSTextField(frame: fieldFrame)
        textField.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        textField.textColor = color
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.isBezeled = false
        textField.isEditable = true
        textField.isSelectable = true
        textField.focusRingType = .none
        textField.placeholderString = "Type text..."
        textField.target = self
        textField.action = #selector(textFieldAction(_:))
        textField.delegate = canvas

        // Make the insertion cursor visible with a contrasting color
        if let fieldEditor = textField.window?.fieldEditor(true, for: textField) as? NSTextView {
            fieldEditor.insertionPointColor = color
        }

        canvas.addSubview(textField)
        textField.becomeFirstResponder()

        // Set insertion point color after becoming first responder
        DispatchQueue.main.async {
            if let editor = textField.currentEditor() as? NSTextView {
                editor.insertionPointColor = self.color
            }
        }

        activeTextField = textField
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {}
    func mouseUp(at point: CGPoint, in canvas: CanvasView) {}

    func cursor() -> NSCursor { .iBeam }

    @objc private func textFieldAction(_ sender: NSTextField) {
        commitActiveText()
    }

    func commitActiveText() {
        guard let textField = activeTextField, let canvas = activeCanvas else { return }

        let text = textField.stringValue
        let origin = textField.frame.origin

        textField.removeFromSuperview()
        activeTextField = nil
        activeBorder?.removeFromSuperview()
        activeBorder = nil

        guard !text.isEmpty else { return }

        let annotation = TextAnnotation(text: text, origin: origin, color: color, fontSize: fontSize)
        canvas.addAnnotation(annotation)
        canvas.registerUndo(annotation: annotation)
        canvas.needsDisplay = true
    }
}

// MARK: - Dashed Border View

class DashedBorderView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let rect = bounds.insetBy(dx: 1, dy: 1)
        context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 3])

        let path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(path)
        context.strokePath()

        // Light background
        context.setFillColor(NSColor.white.withAlphaComponent(0.05).cgColor)
        context.addPath(path)
        context.fillPath()
    }
}
