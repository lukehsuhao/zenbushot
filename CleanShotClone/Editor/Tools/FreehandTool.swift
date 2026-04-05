import AppKit

class FreehandTool: Tool {
    let toolType: ToolType = .freehand
    var color: NSColor = .systemRed
    var strokeWidth: CGFloat = 5
    private var currentAnnotation: FreehandAnnotation?

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        let annotation = FreehandAnnotation(points: [point], color: color, strokeWidth: strokeWidth)
        currentAnnotation = annotation
        canvas.addAnnotation(annotation)
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {
        currentAnnotation?.points.append(point)
        canvas.needsDisplay = true
    }

    func mouseUp(at point: CGPoint, in canvas: CanvasView) {
        guard let annotation = currentAnnotation else { return }
        if annotation.points.count < 3 { canvas.removeAnnotation(annotation) }
        else { canvas.registerUndo(annotation: annotation) }
        currentAnnotation = nil
    }

    func cursor() -> NSCursor { .crosshair }
}
