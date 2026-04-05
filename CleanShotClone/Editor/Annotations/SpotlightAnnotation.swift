import AppKit

class SpotlightAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var color: NSColor = .black
    var strokeWidth: CGFloat = 0
    var dimOpacity: CGFloat = 0.35

    init(rect: CGRect) {
        self.boundingRect = rect
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        // Guard against invalid rect (width/height must be positive for CGPathAddRoundedRect)
        guard boundingRect.width > 0 && boundingRect.height > 0 else { return }

        context.saveGState()

        // Create a path that covers the entire canvas with the spotlight rect cut out
        let outerPath = CGMutablePath()
        outerPath.addRect(CGRect(origin: .zero, size: canvasSize))
        outerPath.addRoundedRect(in: boundingRect, cornerWidth: 8, cornerHeight: 8)

        // Fill with even-odd rule (fills outside the spotlight, not inside)
        context.addPath(outerPath)
        context.setFillColor(NSColor.black.withAlphaComponent(dimOpacity).cgColor)
        context.fillPath(using: .evenOdd)

        // Draw a subtle bright border around the spotlight area
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(2)
        let borderPath = CGPath(roundedRect: boundingRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(borderPath)
        context.strokePath()

        context.restoreGState()
    }

    func hitTest(_ point: CGPoint) -> Bool {
        boundingRect.insetBy(dx: -8, dy: -8).contains(point)
    }

    func copy() -> Annotation {
        let ann = SpotlightAnnotation(rect: boundingRect)
        ann.dimOpacity = dimOpacity
        return ann
    }
}
