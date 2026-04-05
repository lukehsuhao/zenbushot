import AppKit

class TextAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var text: String
    var color: NSColor
    var strokeWidth: CGFloat // used as font size scale
    var fontSize: CGFloat
    var fontName: String

    init(text: String, origin: CGPoint, color: NSColor = .systemRed, fontSize: CGFloat = 18) {
        self.text = text
        self.color = color
        self.strokeWidth = 1
        self.fontSize = fontSize
        self.fontName = NSFont.systemFont(ofSize: fontSize, weight: .medium).fontName

        // Calculate bounding rect from text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        self.boundingRect = CGRect(origin: origin, size: CGSize(width: max(size.width + 8, 60), height: max(size.height + 4, 24)))
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        // Text with subtle shadow for readability (no background fill)
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 1, height: -1)
        shadow.shadowBlurRadius = 3
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: color,
            .shadow: shadow,
        ]

        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        let textPoint = CGPoint(x: boundingRect.origin.x + 4, y: boundingRect.origin.y + 2)
        (text as NSString).draw(at: textPoint, withAttributes: attributes)

        NSGraphicsContext.restoreGraphicsState()
    }

    func hitTest(_ point: CGPoint) -> Bool {
        boundingRect.insetBy(dx: -4, dy: -4).contains(point)
    }

    func copy() -> Annotation {
        let ann = TextAnnotation(text: text, origin: boundingRect.origin, color: color, fontSize: fontSize)
        ann.boundingRect = boundingRect
        return ann
    }
}
