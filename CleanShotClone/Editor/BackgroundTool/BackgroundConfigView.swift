import AppKit

struct BackgroundConfig {
    var padding: CGFloat = 60
    var cornerRadius: CGFloat = 12
    var hasShadow: Bool = true
    var backgroundType: BackgroundType = .gradient(GradientPreset.presets[0])

    enum BackgroundType {
        case solidColor(NSColor)
        case gradient(GradientPreset)
    }
}

struct GradientPreset {
    let name: String
    let startColor: NSColor
    let endColor: NSColor
    let angle: CGFloat

    static let presets: [GradientPreset] = [
        GradientPreset(name: "Ocean", startColor: NSColor(hex: "#667eea")!, endColor: NSColor(hex: "#764ba2")!, angle: 135),
        GradientPreset(name: "Sunset", startColor: NSColor(hex: "#f093fb")!, endColor: NSColor(hex: "#f5576c")!, angle: 135),
        GradientPreset(name: "Forest", startColor: NSColor(hex: "#11998e")!, endColor: NSColor(hex: "#38ef7d")!, angle: 135),
        GradientPreset(name: "Fire", startColor: NSColor(hex: "#f12711")!, endColor: NSColor(hex: "#f5af19")!, angle: 135),
        GradientPreset(name: "Sky", startColor: NSColor(hex: "#89f7fe")!, endColor: NSColor(hex: "#66a6ff")!, angle: 135),
        GradientPreset(name: "Night", startColor: NSColor(hex: "#0f0c29")!, endColor: NSColor(hex: "#302b63")!, angle: 135),
        GradientPreset(name: "Rose", startColor: NSColor(hex: "#ee9ca7")!, endColor: NSColor(hex: "#ffdde1")!, angle: 135),
        GradientPreset(name: "Midnight", startColor: NSColor(hex: "#232526")!, endColor: NSColor(hex: "#414345")!, angle: 135),
    ]
}

class BackgroundConfigPanel {
    private static var currentPanel: NSPanel?
    private static var config = BackgroundConfig()
    private static var applyHandler: ((BackgroundConfig) -> Void)?

    static func show(from button: NSView, applyHandler: @escaping (BackgroundConfig) -> Void) {
        dismiss()
        self.applyHandler = applyHandler

        guard let screen = NSScreen.main else { return }
        let buttonFrame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero

        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 360

        let panelFrame = CGRect(
            x: buttonFrame.midX - panelWidth / 2,
            y: buttonFrame.maxY + 8,
            width: panelWidth,
            height: panelHeight
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Background"
        panel.level = .floating
        panel.isFloatingPanel = true

        let contentView = NSView(frame: NSRect(origin: .zero, size: panelFrame.size))
        var y: CGFloat = panelHeight - 40

        // Gradient presets label
        let presetsLabel = NSTextField(labelWithString: "Gradient Presets")
        presetsLabel.frame = CGRect(x: 12, y: y, width: 200, height: 18)
        presetsLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        contentView.addSubview(presetsLabel)
        y -= 8

        // Gradient preset grid (2 rows of 4)
        let presets = GradientPreset.presets
        let swatchSize: CGFloat = 56
        let swatchSpacing: CGFloat = 8
        for (i, preset) in presets.enumerated() {
            let col = i % 4
            let row = i / 4
            let x: CGFloat = 12 + CGFloat(col) * (swatchSize + swatchSpacing)
            let vy = y - CGFloat(row + 1) * (swatchSize + swatchSpacing)

            let swatch = GradientSwatchView(
                frame: NSRect(x: x, y: vy, width: swatchSize, height: swatchSize),
                preset: preset,
                index: i
            )
            swatch.onClick = { idx in
                config.backgroundType = .gradient(presets[idx])
                applyHandler(config)
            }
            contentView.addSubview(swatch)
        }
        y -= CGFloat((presets.count + 3) / 4) * (swatchSize + swatchSpacing) + 12

        // Padding slider
        let paddingLabel = NSTextField(labelWithString: "Padding")
        paddingLabel.frame = CGRect(x: 12, y: y, width: 60, height: 18)
        paddingLabel.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(paddingLabel)

        let paddingSlider = NSSlider(frame: CGRect(x: 80, y: y, width: 140, height: 18))
        paddingSlider.minValue = 20
        paddingSlider.maxValue = 120
        paddingSlider.doubleValue = Double(config.padding)
        paddingSlider.target = BackgroundConfigPanel.self
        paddingSlider.action = #selector(paddingChanged(_:))
        contentView.addSubview(paddingSlider)

        let paddingVal = NSTextField(labelWithString: "\(Int(config.padding))")
        paddingVal.frame = CGRect(x: 228, y: y, width: 40, height: 18)
        paddingVal.font = Theme.Fonts.strokeValue
        paddingVal.tag = 400
        contentView.addSubview(paddingVal)
        y -= 30

        // Corner radius
        let radiusLabel = NSTextField(labelWithString: "Corners")
        radiusLabel.frame = CGRect(x: 12, y: y, width: 60, height: 18)
        radiusLabel.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(radiusLabel)

        let radiusSlider = NSSlider(frame: CGRect(x: 80, y: y, width: 140, height: 18))
        radiusSlider.minValue = 0
        radiusSlider.maxValue = 24
        radiusSlider.doubleValue = Double(config.cornerRadius)
        radiusSlider.target = BackgroundConfigPanel.self
        radiusSlider.action = #selector(radiusChanged(_:))
        contentView.addSubview(radiusSlider)
        y -= 30

        // Shadow toggle
        let shadowCheck = NSButton(checkboxWithTitle: "Drop shadow", target: BackgroundConfigPanel.self, action: #selector(shadowToggled(_:)))
        shadowCheck.state = config.hasShadow ? .on : .off
        shadowCheck.frame.origin = CGPoint(x: 12, y: y)
        contentView.addSubview(shadowCheck)
        y -= 36

        // Apply button
        let applyBtn = NSButton(title: "Apply Background", target: BackgroundConfigPanel.self, action: #selector(applyClicked))
        applyBtn.frame = CGRect(x: 12, y: y, width: 256, height: 28)
        applyBtn.bezelStyle = .rounded
        contentView.addSubview(applyBtn)

        panel.contentView = contentView
        panel.makeKeyAndOrderFront(nil)
        currentPanel = panel
    }

    static func dismiss() {
        currentPanel?.orderOut(nil)
        currentPanel = nil
    }

    @objc static func paddingChanged(_ sender: NSSlider) {
        config.padding = CGFloat(sender.doubleValue)
        if let label = currentPanel?.contentView?.viewWithTag(400) as? NSTextField {
            label.stringValue = "\(Int(config.padding))"
        }
    }

    @objc static func radiusChanged(_ sender: NSSlider) {
        config.cornerRadius = CGFloat(sender.doubleValue)
    }

    @objc static func shadowToggled(_ sender: NSButton) {
        config.hasShadow = sender.state == .on
    }

    @objc static func applyClicked() {
        applyHandler?(config)
        dismiss()
    }

    static func applyBackground(_ config: BackgroundConfig, to image: NSImage) -> NSImage {
        let padding = config.padding
        let totalSize = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )
        let result = NSImage(size: totalSize)
        result.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            result.unlockFocus()
            return image
        }

        let fullRect = CGRect(origin: .zero, size: totalSize)

        // Draw background
        switch config.backgroundType {
        case .solidColor(let color):
            context.setFillColor(color.cgColor)
            context.fill(fullRect)

        case .gradient(let preset):
            let colors = [preset.startColor.cgColor, preset.endColor.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { break }
            let angleRad = preset.angle * .pi / 180
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: totalSize.width * cos(angleRad), y: totalSize.height * sin(angleRad))
            context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        }

        // Draw shadow
        let imageRect = CGRect(x: padding, y: padding, width: image.size.width, height: image.size.height)
        if config.hasShadow {
            context.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        }

        // Draw rounded screenshot
        if config.cornerRadius > 0 {
            let clipPath = CGPath(roundedRect: imageRect, cornerWidth: config.cornerRadius, cornerHeight: config.cornerRadius, transform: nil)
            context.saveGState()
            context.addPath(clipPath)
            context.clip()
        }

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: imageRect)
        }

        if config.cornerRadius > 0 {
            context.restoreGState()
        }

        result.unlockFocus()
        return result
    }
}

// MARK: - Gradient Swatch

class GradientSwatchView: NSView {
    var onClick: ((Int) -> Void)?
    private let preset: GradientPreset
    private let index: Int

    init(frame: NSRect, preset: GradientPreset, index: Int) {
        self.preset = preset
        self.index = index
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        toolTip = preset.name
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let colors = [preset.startColor.cgColor, preset.endColor.cgColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: bounds.width, y: bounds.height), options: [])
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(index)
    }
}
