import AppKit

class SelectionTool: Tool {
    let toolType: ToolType = .selection
    private var isDragging = false
    private var lastClickTime: TimeInterval = 0
    private var lastClickPoint: CGPoint = .zero

    func mouseDown(at point: CGPoint, in canvas: CanvasView) {
        let selection = canvas.selectionState

        // Check for double-click on text annotation
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastClickTime < 0.3 {
            let dist = hypot(point.x - lastClickPoint.x, point.y - lastClickPoint.y)
            if dist < 5, let textAnn = selection.selectedAnnotation as? TextAnnotation {
                canvas.startEditingText(textAnn)
                return
            }
        }
        lastClickTime = now
        lastClickPoint = point

        // Check if clicking on a handle of the selected annotation
        if selection.isSelected {
            if let handle = selection.handleAt(point) {
                selection.dragHandle = handle
                selection.dragStartPoint = point
                selection.originalBoundingRect = selection.selectedAnnotation?.boundingRect
                if let arrow = selection.selectedAnnotation as? ArrowAnnotation {
                    selection.originalStartPoint = arrow.startPoint
                    selection.originalEndPoint = arrow.endPoint
                }
                isDragging = true
                return
            }
        }

        // Hit test annotations in reverse order (topmost first)
        var foundAnnotation: Annotation?
        for annotation in canvas.annotations.reversed() {
            if annotation.hitTest(point) {
                foundAnnotation = annotation
                break
            }
        }

        if let annotation = foundAnnotation {
            selection.selectedAnnotation = annotation
            selection.dragHandle = nil
            selection.dragStartPoint = point
            selection.originalBoundingRect = annotation.boundingRect
            if let arrow = annotation as? ArrowAnnotation {
                selection.originalStartPoint = arrow.startPoint
                selection.originalEndPoint = arrow.endPoint
            }
            isDragging = true
        } else {
            selection.clear()
        }

        canvas.needsDisplay = true
    }

    func mouseDragged(to point: CGPoint, in canvas: CanvasView) {
        guard isDragging else { return }
        let selection = canvas.selectionState
        guard let annotation = selection.selectedAnnotation,
              let startPoint = selection.dragStartPoint else { return }

        let dx = point.x - startPoint.x
        let dy = point.y - startPoint.y

        if let handle = selection.dragHandle {
            // Resize
            if let arrow = annotation as? ArrowAnnotation,
               let origStart = selection.originalStartPoint,
               let origEnd = selection.originalEndPoint {
                // For arrows, move the nearest endpoint
                let distToStart = hypot(startPoint.x - origStart.x, startPoint.y - origStart.y)
                let distToEnd = hypot(startPoint.x - origEnd.x, startPoint.y - origEnd.y)
                if distToStart < distToEnd {
                    arrow.startPoint = CGPoint(x: origStart.x + dx, y: origStart.y + dy)
                } else {
                    arrow.endPoint = CGPoint(x: origEnd.x + dx, y: origEnd.y + dy)
                }
            } else if let origRect = selection.originalBoundingRect {
                var newRect = origRect
                switch handle {
                case .topLeft:
                    newRect.origin.x += dx
                    newRect.size.width -= dx
                    newRect.size.height += dy
                case .top:
                    newRect.size.height += dy
                case .topRight:
                    newRect.size.width += dx
                    newRect.size.height += dy
                case .left:
                    newRect.origin.x += dx
                    newRect.size.width -= dx
                case .right:
                    newRect.size.width += dx
                case .bottomLeft:
                    newRect.origin.x += dx
                    newRect.size.width -= dx
                    newRect.origin.y += dy
                    newRect.size.height -= dy
                case .bottom:
                    newRect.origin.y += dy
                    newRect.size.height -= dy
                case .bottomRight:
                    newRect.size.width += dx
                    newRect.origin.y += dy
                    newRect.size.height -= dy
                }
                // Enforce minimum size
                if newRect.width >= 10 && newRect.height >= 10 {
                    annotation.resize(to: newRect)
                    if let blur = annotation as? BlurAnnotation { blur.invalidateCache() }
                    if let mosaic = annotation as? MosaicAnnotation { mosaic.invalidateCache() }
                }
            }
        } else {
            // Move
            if let arrow = annotation as? ArrowAnnotation,
               let origStart = selection.originalStartPoint,
               let origEnd = selection.originalEndPoint {
                arrow.startPoint = CGPoint(x: origStart.x + dx, y: origStart.y + dy)
                arrow.endPoint = CGPoint(x: origEnd.x + dx, y: origEnd.y + dy)
            } else if annotation is LineAnnotation,
                      let line = annotation as? LineAnnotation,
                      let origStart = selection.originalStartPoint,
                      let origEnd = selection.originalEndPoint {
                line.startPoint = CGPoint(x: origStart.x + dx, y: origStart.y + dy)
                line.endPoint = CGPoint(x: origEnd.x + dx, y: origEnd.y + dy)
            } else if let origRect = selection.originalBoundingRect {
                annotation.move(by: CGSize(width: dx, height: dy))
                annotation.boundingRect.origin = CGPoint(
                    x: origRect.origin.x + dx,
                    y: origRect.origin.y + dy
                )
                if let blur = annotation as? BlurAnnotation { blur.invalidateCache() }
                if let mosaic = annotation as? MosaicAnnotation { mosaic.invalidateCache() }
            }
        }

        canvas.needsDisplay = true
    }

    func mouseUp(at point: CGPoint, in canvas: CanvasView) {
        if isDragging {
            let selection = canvas.selectionState
            if let annotation = selection.selectedAnnotation,
               let origRect = selection.originalBoundingRect {
                canvas.registerMoveUndo(annotation: annotation, previousRect: origRect,
                                       previousStart: selection.originalStartPoint,
                                       previousEnd: selection.originalEndPoint)
            }
        }
        isDragging = false
    }

    func cursor() -> NSCursor { .arrow }
}
