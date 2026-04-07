import AppKit

enum ToolType: String, CaseIterable {
    case selection = "Select"
    case hand = "Hand"
    case arrow = "Arrow"
    case line = "Line"
    case rectangle = "Rectangle"
    case roundedRect = "Rounded Rect"
    case ellipse = "Ellipse"
    case freehand = "Pencil"
    case text = "Text"
    case counter = "Counter"
    case highlighter = "Highlight"
    case blur = "Blur"
    case mosaic = "Mosaic"
    case spotlight = "Spotlight"

    var icon: String {
        switch self {
        case .selection: return "cursorarrow"
        case .hand: return "hand.raised"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .roundedRect: return "app"
        case .ellipse: return "circle"
        case .freehand: return "pencil.tip"
        case .text: return "textformat"
        case .counter: return "number"
        case .highlighter: return "highlighter"
        case .blur: return "aqi.medium"
        case .mosaic: return "squareshape.split.3x3"
        case .spotlight: return "sparkles.rectangle.stack"
        }
    }
}

protocol Tool {
    var toolType: ToolType { get }
    func mouseDown(at point: CGPoint, in canvas: CanvasView)
    func mouseDragged(to point: CGPoint, in canvas: CanvasView)
    func mouseUp(at point: CGPoint, in canvas: CanvasView)
    func cursor() -> NSCursor
}
