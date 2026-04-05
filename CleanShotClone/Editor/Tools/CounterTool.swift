import AppKit

class CounterTool: Tool {
    let toolType: ToolType = .counter
    var color: NSColor = .systemRed
    var nextNumber: Int = 1

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        let annotation = CounterAnnotation(center: point, number: nextNumber, color: color)
        canvas.addAnnotation(annotation)
        canvas.registerUndo(annotation: annotation)
        nextNumber += 1
        canvas.needsDisplay = true
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {}
    func mouseUp(at point: CGPoint, in canvas: CanvasView) {}
    func cursor() -> NSCursor { .crosshair }

    func resetCounter() { nextNumber = 1 }
}
