import AppKit

class LineTool: Tool {
    let toolType: ToolType = .line
    var color: NSColor = .systemRed
    var strokeWidth: CGFloat = 5
    private var currentAnnotation: LineAnnotation?

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        let annotation = LineAnnotation(start: point, end: point, color: color, strokeWidth: strokeWidth)
        currentAnnotation = annotation
        canvas.addAnnotation(annotation)
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {
        currentAnnotation?.endPoint = point
        canvas.needsDisplay = true
    }

    func mouseUp(at point: CGPoint, in canvas: CanvasView) {
        guard let annotation = currentAnnotation else { return }
        let dx = annotation.endPoint.x - annotation.startPoint.x
        let dy = annotation.endPoint.y - annotation.startPoint.y
        if sqrt(dx * dx + dy * dy) < 5 { canvas.removeAnnotation(annotation) }
        else { canvas.registerUndo(annotation: annotation) }
        currentAnnotation = nil
    }

    func cursor() -> NSCursor { .crosshair }
}
