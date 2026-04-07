import AppKit

class RoundedRectAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var color: NSColor       // border color
    var fillColor: NSColor   // fill color (.clear = no fill)
    var strokeWidth: CGFloat
    var cornerRadius: CGFloat = 12

    init(rect: CGRect, color: NSColor = .systemRed, fillColor: NSColor = .clear, strokeWidth: CGFloat = 3) {
        self.boundingRect = rect
        self.color = color
        self.fillColor = fillColor
        self.strokeWidth = strokeWidth
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        guard boundingRect.width > 0, boundingRect.height > 0 else { return }
        let path = CGPath(roundedRect: boundingRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        if fillColor != .clear {
            context.addPath(path)
            context.setFillColor(fillColor.cgColor)
            context.fillPath()
        }

        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth)
        context.strokePath()
    }

    func hitTest(_ point: CGPoint) -> Bool {
        boundingRect.insetBy(dx: -strokeWidth, dy: -strokeWidth).contains(point)
    }

    func copy() -> Annotation {
        let ann = RoundedRectAnnotation(rect: boundingRect, color: color, fillColor: fillColor, strokeWidth: strokeWidth)
        ann.cornerRadius = cornerRadius
        return ann
    }
}
