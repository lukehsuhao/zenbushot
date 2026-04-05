import AppKit

class LineAnnotation: Annotation {
    let id = UUID()
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var strokeWidth: CGFloat
    var boundingRect: CGRect {
        get {
            CGRect(
                x: min(startPoint.x, endPoint.x) - strokeWidth,
                y: min(startPoint.y, endPoint.y) - strokeWidth,
                width: abs(endPoint.x - startPoint.x) + strokeWidth * 2,
                height: abs(endPoint.y - startPoint.y) + strokeWidth * 2
            )
        }
        set {}
    }

    init(start: CGPoint, end: CGPoint, color: NSColor = .systemRed, strokeWidth: CGFloat = 3) {
        self.startPoint = start
        self.endPoint = end
        self.color = color
        self.strokeWidth = strokeWidth
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
    }

    func hitTest(_ point: CGPoint) -> Bool {
        let tolerance: CGFloat = 8
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return false }
        let t = max(0, min(1, ((point.x - startPoint.x) * dx + (point.y - startPoint.y) * dy) / (length * length)))
        let closestX = startPoint.x + t * dx
        let closestY = startPoint.y + t * dy
        let distance = sqrt(pow(point.x - closestX, 2) + pow(point.y - closestY, 2))
        return distance <= tolerance
    }

    func copy() -> Annotation { LineAnnotation(start: startPoint, end: endPoint, color: color, strokeWidth: strokeWidth) }

    func move(by delta: CGSize) {
        startPoint.x += delta.width; startPoint.y += delta.height
        endPoint.x += delta.width; endPoint.y += delta.height
    }
}
