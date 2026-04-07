import AppKit

class HandTool: Tool {
    let toolType: ToolType = .hand
    private var lastPoint: CGPoint?

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        lastPoint = point
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {
        guard let last = lastPoint, let scrollView = canvas.enclosingScrollView else { return }

        let dx = point.x - last.x
        let dy = point.y - last.y

        var origin = scrollView.contentView.bounds.origin
        origin.x -= dx
        origin.y -= dy

        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        // Don't update lastPoint — it's in canvas coords which shift with scroll
    }

    func mouseUp(at point: CGPoint, in canvas: CanvasView) {
        lastPoint = nil
    }

    func cursor() -> NSCursor { .openHand }
}
