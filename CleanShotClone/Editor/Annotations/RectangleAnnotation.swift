import AppKit

class RectangleAnnotation: Annotation {
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
        let rect = boundingRect

        if isFilled {
            context.setFillColor(color.withAlphaComponent(0.3).cgColor)
            context.fill(rect)
        }

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth)
        context.stroke(rect)
    }

    func hitTest(_ point: CGPoint) -> Bool {
        let tolerance: CGFloat = 8
        let outerRect = boundingRect.insetBy(dx: -tolerance, dy: -tolerance)
        let innerRect = boundingRect.insetBy(dx: tolerance, dy: tolerance)

        if isFilled {
            return outerRect.contains(point)
        }
        return outerRect.contains(point) && !innerRect.contains(point)
    }

    func copy() -> Annotation {
        RectangleAnnotation(rect: boundingRect, color: color, strokeWidth: strokeWidth, isFilled: isFilled)
    }
}
