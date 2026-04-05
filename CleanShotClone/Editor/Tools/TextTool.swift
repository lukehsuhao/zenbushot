import AppKit

class TextTool: Tool {
    let toolType: ToolType = .text
    var color: NSColor = .systemRed
    var fontSize: CGFloat = 18
    private weak var activeTextField: NSTextField?
    private weak var activeCanvas: CanvasView?

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        // Commit any existing text first
        commitActiveText()

        activeCanvas = canvas

        // Create inline text field
        let textField = NSTextField(frame: CGRect(x: point.x, y: point.y - 12, width: 200, height: 28))
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

        canvas.addSubview(textField)
        textField.becomeFirstResponder()

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

        guard !text.isEmpty else { return }

        let annotation = TextAnnotation(text: text, origin: origin, color: color, fontSize: fontSize)
        canvas.addAnnotation(annotation)
        canvas.registerUndo(annotation: annotation)
        canvas.needsDisplay = true
    }
}
