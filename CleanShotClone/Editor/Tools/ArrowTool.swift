import AppKit

class ArrowTool: Tool {
    let toolType: ToolType = .arrow
    var color: NSColor = .systemRed
    var strokeWidth: CGFloat = 5
    private var currentAnnotation: ArrowAnnotation?

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        let annotation = ArrowAnnotation(start: point, end: point, color: color, strokeWidth: strokeWidth)
        currentAnnotation = annotation
        canvas.addAnnotation(annotation)
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {
        guard let annotation = currentAnnotation else { return }
        annotation.endPoint = point
        canvas.needsDisplay = true
    }

    func mouseUp(at point: CGPoint, in canvas: CanvasView) {
        guard let annotation = currentAnnotation else { return }
        // Remove if too small
        let dx = annotation.endPoint.x - annotation.startPoint.x
        let dy = annotation.endPoint.y - annotation.startPoint.y
        if sqrt(dx * dx + dy * dy) < 5 {
            canvas.removeAnnotation(annotation)
        } else {
            canvas.registerUndo(annotation: annotation)
        }
        currentAnnotation = nil
    }

    func cursor() -> NSCursor { .crosshair }
}
