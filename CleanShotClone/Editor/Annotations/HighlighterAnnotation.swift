import AppKit

class HighlighterAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var color: NSColor
    var strokeWidth: CGFloat = 0

    init(rect: CGRect, color: NSColor = .systemYellow) {
        self.boundingRect = rect
        self.color = color
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        context.saveGState()
        context.setBlendMode(.multiply)
        context.setFillColor(color.withAlphaComponent(0.4).cgColor)
        context.fill(boundingRect)
        context.restoreGState()
    }

    func hitTest(_ point: CGPoint) -> Bool {
        boundingRect.contains(point)
    }

    func copy() -> Annotation { HighlighterAnnotation(rect: boundingRect, color: color) }
}
