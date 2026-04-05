import AppKit

class CounterAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var color: NSColor
    var strokeWidth: CGFloat = 1
    var number: Int
    var circleSize: CGFloat = 28

    init(center: CGPoint, number: Int, color: NSColor = .systemRed) {
        self.number = number
        self.color = color
        self.boundingRect = CGRect(
            x: center.x - circleSize / 2,
            y: center.y - circleSize / 2,
            width: circleSize,
            height: circleSize
        )
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        // Draw filled circle
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: boundingRect)

        // Draw number
        let text = "\(number)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: circleSize * 0.55, weight: .bold),
            .foregroundColor: NSColor.white,
        ]

        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        let textSize = text.size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: boundingRect.midX - textSize.width / 2,
            y: boundingRect.midY - textSize.height / 2
        )
        text.draw(at: textPoint, withAttributes: attributes)

        NSGraphicsContext.restoreGraphicsState()
    }

    func hitTest(_ point: CGPoint) -> Bool {
        let dx = point.x - boundingRect.midX
        let dy = point.y - boundingRect.midY
        let r = circleSize / 2
        return (dx * dx + dy * dy) <= (r * r)
    }

    func copy() -> Annotation {
        let ann = CounterAnnotation(center: CGPoint(x: boundingRect.midX, y: boundingRect.midY), number: number, color: color)
        ann.circleSize = circleSize
        return ann
    }
}
