import AppKit

class RoundedRectangleTool: Tool {
    let toolType: ToolType = .roundedRect
    var color: NSColor = .systemRed
    var fillColor: NSColor = .clear
    var strokeWidth: CGFloat = 5
    private var startPoint: CGPoint?
    private var currentAnnotation: RoundedRectAnnotation?

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        startPoint = point
        let annotation = RoundedRectAnnotation(rect: CGRect(origin: point, size: .zero), color: color, fillColor: fillColor, strokeWidth: strokeWidth)
        currentAnnotation = annotation
        canvas.addAnnotation(annotation)
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {
        guard let start = startPoint, let annotation = currentAnnotation else { return }
        var w = abs(point.x - start.x)
        var h = abs(point.y - start.y)

        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) || flags.contains(.command) {
            let side = max(w, h)
            w = side; h = side
        }

        annotation.boundingRect = CGRect(
            x: point.x >= start.x ? start.x : start.x - w,
            y: point.y >= start.y ? start.y : start.y - h,
            width: w, height: h
        )
        canvas.needsDisplay = true
    }

    func mouseUp(at point: CGPoint, in canvas: CanvasView) {
        guard let annotation = currentAnnotation else { return }
        if annotation.boundingRect.width < 5 || annotation.boundingRect.height < 5 {
            canvas.removeAnnotation(annotation)
        } else {
            canvas.registerUndo(annotation: annotation)
        }
        currentAnnotation = nil
        startPoint = nil
    }

    func cursor() -> NSCursor { .crosshair }
}
