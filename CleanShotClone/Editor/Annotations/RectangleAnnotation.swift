import AppKit

class RectangleAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var color: NSColor       // border color
    var fillColor: NSColor   // fill color (.clear = no fill)
    var strokeWidth: CGFloat

    init(rect: CGRect, color: NSColor = .systemRed, fillColor: NSColor = .clear, strokeWidth: CGFloat = 3) {
        self.boundingRect = rect
        self.color = color
        self.fillColor = fillColor
        self.strokeWidth = strokeWidth
    }

    // Legacy support
    var isFilled: Bool { fillColor != .clear }

    func render(in context: CGContext, canvasSize: CGSize) {
        let rect = boundingRect

        if fillColor != .clear {
            context.setFillColor(fillColor.cgColor)
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

        if fillColor != .clear {
            return outerRect.contains(point)
        }
        return outerRect.contains(point) && !innerRect.contains(point)
    }

    func copy() -> Annotation {
        RectangleAnnotation(rect: boundingRect, color: color, fillColor: fillColor, strokeWidth: strokeWidth)
    }
}
