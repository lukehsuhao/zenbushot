import AppKit

class FreehandAnnotation: Annotation {
    let id = UUID()
    var points: [CGPoint]
    var color: NSColor
    var strokeWidth: CGFloat
    var boundingRect: CGRect {
        get {
            guard !points.isEmpty else { return .zero }
            var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
            for p in points {
                minX = min(minX, p.x); minY = min(minY, p.y)
                maxX = max(maxX, p.x); maxY = max(maxY, p.y)
            }
            return CGRect(x: minX - strokeWidth, y: minY - strokeWidth,
                          width: maxX - minX + strokeWidth * 2, height: maxY - minY + strokeWidth * 2)
        }
        set {}
    }

    init(points: [CGPoint] = [], color: NSColor = .systemRed, strokeWidth: CGFloat = 3) {
        self.points = points
        self.color = color
        self.strokeWidth = strokeWidth
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        guard points.count >= 2 else { return }
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()
    }

    func hitTest(_ point: CGPoint) -> Bool {
        let tolerance: CGFloat = 8
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = sqrt(dx * dx + dy * dy)
            guard len > 0 else { continue }
            let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / (len * len)))
            let closestX = a.x + t * dx, closestY = a.y + t * dy
            if sqrt(pow(point.x - closestX, 2) + pow(point.y - closestY, 2)) <= tolerance { return true }
        }
        return false
    }

    func copy() -> Annotation { FreehandAnnotation(points: points, color: color, strokeWidth: strokeWidth) }

    func move(by delta: CGSize) {
        points = points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
    }
}
