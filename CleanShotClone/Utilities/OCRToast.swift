import AppKit

/// Floating toast notification for OCR results — appears top-right, auto-dismisses after 3 seconds
class OCRToast {
    private static var currentPanel: NSPanel?
    private static var dismissTimer: Timer?

    static func show(text: String?) {
        dismiss()

        guard let screen = NSScreen.main else { return }

        let toastWidth: CGFloat = 360

        let title: String
        let body: String

        if let text = text, !text.isEmpty {
            let charCount = text.count
            title = L("ocr.copied", charCount)
            body = text
        } else {
            title = L("ocr.title")
            body = L("ocr.notext")
        }

        // Calculate how tall the toast needs to be based on text content
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let maxBodyHeight: CGFloat = 300
        let bodySize = (body as NSString).boundingRect(
            with: NSSize(width: toastWidth - 32, height: maxBodyHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: bodyFont]
        )
        let bodyHeight = min(ceil(bodySize.height) + 4, maxBodyHeight)
        let finalHeight = bodyHeight + 46  // 28 title + 10 bottom padding + 8 gap

        // Position: top-right corner of screen
        let margin: CGFloat = 16
        let x = screen.visibleFrame.maxX - toastWidth - margin
        let y = screen.visibleFrame.maxY - finalHeight - margin

        let panel = NSPanel(
            contentRect: CGRect(x: x, y: y, width: toastWidth, height: finalHeight),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: CGSize(width: toastWidth, height: finalHeight)))
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12

        // Title label
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.frame = NSRect(x: 16, y: finalHeight - 28, width: toastWidth - 32, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        bg.addSubview(titleLabel)

        // Body label — show as much text as fits
        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.frame = NSRect(x: 16, y: 10, width: toastWidth - 32, height: bodyHeight)
        bodyLabel.font = bodyFont
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bg.addSubview(bodyLabel)

        panel.contentView = bg

        // Slide in from right
        let startFrame = CGRect(x: x + 40, y: y, width: toastWidth, height: finalHeight)
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().setFrame(CGRect(x: x, y: y, width: toastWidth, height: finalHeight), display: true)
            panel.animator().alphaValue = 1
        }

        currentPanel = panel

        // Auto-dismiss after 3 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            dismissAnimated()
        }
    }

    private static func dismissAnimated() {
        guard let panel = currentPanel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            currentPanel = nil
        })
    }

    static func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentPanel?.orderOut(nil)
        currentPanel = nil
    }
}
