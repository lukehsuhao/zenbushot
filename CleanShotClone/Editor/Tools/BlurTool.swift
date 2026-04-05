import AppKit

class BlurTool: Tool {
    let toolType: ToolType = .blur
    private var startPoint: CGPoint?
    private var currentAnnotation: BlurAnnotation?

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        startPoint = point
        let annotation = BlurAnnotation(rect: CGRect(origin: point, size: .zero))
        currentAnnotation = annotation
        canvas.addAnnotation(annotation)
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {
        guard let start = startPoint, let annotation = currentAnnotation else { return }
        annotation.boundingRect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        )
        annotation.invalidateCache()
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
