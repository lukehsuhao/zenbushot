import AppKit

class EllipseAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var color: NSColor
    var strokeWidth: CGFloat
    var isFilled: Bool

    init(rect: CGRect, color: NSColor = .systemRed, strokeWidth: CGFloat = 3, isFilled: Bool = false) {
        self.boundingRect = rect
        self.color = color
        self.strokeWidth = strokeWidth
        self.isFilled = isFilled
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        if isFilled {
            context.setFillColor(color.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: boundingRect)
        }
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth)
        context.strokeEllipse(in: boundingRect)
    }

    func hitTest(_ point: CGPoint) -> Bool {
        let a = boundingRect.width / 2
        let b = boundingRect.height / 2
        let cx = boundingRect.midX
        let cy = boundingRect.midY
        let dx = point.x - cx
        let dy = point.y - cy
        let dist = (dx * dx) / (a * a) + (dy * dy) / (b * b)
        if isFilled { return dist <= 1.0 }
        return abs(dist - 1.0) < 0.3
    }

    func copy() -> Annotation { EllipseAnnotation(rect: boundingRect, color: color, strokeWidth: strokeWidth, isFilled: isFilled) }
}
