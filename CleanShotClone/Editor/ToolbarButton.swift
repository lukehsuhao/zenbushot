import AppKit

class ToolbarButton: NSView {
    var icon: NSImage?
    var toolTipText: String = ""
    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var onClicked: (() -> Void)?

    private var isHovered = false
    private var isPressed = false
    private var trackingArea: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        NSSize(width: Theme.Dimensions.toolButtonSize, height: Theme.Dimensions.toolButtonSize)
    }

    init(icon: NSImage?, toolTip: String) {
        self.icon = icon
        self.toolTipText = toolTip
        super.init(frame: NSRect(x: 0, y: 0, width: Theme.Dimensions.toolButtonSize, height: Theme.Dimensions.toolButtonSize))
        self.toolTip = toolTip
        wantsLayer = true
        layer?.cornerRadius = 5
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds.insetBy(dx: 1, dy: 1)

        // Background
        if isSelected {
            context.setFillColor(Theme.Colors.buttonSelected.cgColor)
            let path = CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: nil)
            context.addPath(path)
            context.fillPath()
        } else if isHovered {
            context.setFillColor(Theme.Colors.buttonHover.cgColor)
            let path = CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: nil)
            context.addPath(path)
            context.fillPath()
        }

        // Icon
        guard let icon = icon else { return }

        let tintColor = isSelected ? Theme.Colors.buttonSelectedTint : NSColor.labelColor
        let tintedIcon = icon.copy() as! NSImage
        tintedIcon.lockFocus()
        tintColor.set()
        NSRect(origin: .zero, size: tintedIcon.size).fill(using: .sourceAtop)
        tintedIcon.unlockFocus()

        let iconSize: CGFloat = 14
        let iconRect = NSRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        tintedIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: isPressed ? 0.6 : 1.0)
    }

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true

        // Scale-down animation
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Theme.Animation.buttonPress
            self.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 0.92, y: 0.92))
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false

        // Scale-up animation
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Theme.Animation.buttonPress
            self.animator().layer?.setAffineTransform(.identity)
        }

        let locationInView = convert(event.locationInWindow, from: nil)
        if bounds.contains(locationInView) {
            onClicked?()
        }

        needsDisplay = true
    }
}
