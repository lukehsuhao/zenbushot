import AppKit

class SelectionState {
    var selectedAnnotation: Annotation?
    var dragHandle: HandlePosition?
    var dragStartPoint: CGPoint?
    var originalBoundingRect: CGRect?
    var originalStartPoint: CGPoint? // For ArrowAnnotation
    var originalEndPoint: CGPoint?   // For ArrowAnnotation

    var isSelected: Bool { selectedAnnotation != nil }

    func clear() {
        selectedAnnotation = nil
        dragHandle = nil
        dragStartPoint = nil
        originalBoundingRect = nil
        originalStartPoint = nil
        originalEndPoint = nil
    }

    func handleAt(_ point: CGPoint) -> HandlePosition? {
        guard let annotation = selectedAnnotation else { return nil }
        let rect = annotation.boundingRect
        let tolerance: CGFloat = 8

        for handle in HandlePosition.allCases {
            let handlePoint = handle.point(in: rect)
            if abs(point.x - handlePoint.x) <= tolerance && abs(point.y - handlePoint.y) <= tolerance {
                return handle
            }
        }
        return nil
    }

    func cursorForHandle(_ handle: HandlePosition?) -> NSCursor {
        guard let handle = handle else { return .openHand }
        switch handle {
        case .topLeft, .bottomRight: return .crosshair
        case .topRight, .bottomLeft: return .crosshair
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        }
    }
}
