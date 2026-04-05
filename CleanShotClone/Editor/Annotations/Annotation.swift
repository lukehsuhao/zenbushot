import AppKit

protocol Annotation: AnyObject {
    var id: UUID { get }
    var boundingRect: CGRect { get set }
    var color: NSColor { get set }
    var strokeWidth: CGFloat { get set }
    func render(in context: CGContext, canvasSize: CGSize)
    func hitTest(_ point: CGPoint) -> Bool
    func copy() -> Annotation
    func move(by delta: CGSize)
    func resize(to newRect: CGRect)
}

// Default implementations
extension Annotation {
    func move(by delta: CGSize) {
        boundingRect.origin.x += delta.width
        boundingRect.origin.y += delta.height
    }

    func resize(to newRect: CGRect) {
        boundingRect = newRect
    }
}

enum HandlePosition: CaseIterable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .top: return CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.minY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.minY)
        }
    }
}
