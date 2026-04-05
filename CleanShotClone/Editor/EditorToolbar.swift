import AppKit

protocol EditorToolbarDelegate: AnyObject {
    func toolbarDidSelectTool(_ toolType: ToolType)
    func toolbarDidChangeColor(_ color: NSColor)
    func toolbarDidChangeStrokeWidth(_ width: CGFloat)
}

class EditorToolbar: NSView {
    weak var delegate: EditorToolbarDelegate?
    private var toolButtons: [ToolType: ToolbarButton] = [:]
    private var selectedToolType: ToolType = .selection
    private var colorButton: NSView!
    private var currentColor: NSColor = Theme.Colors.defaultAnnotationColor

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // Tool groups for visual organization
    private let toolGroups: [[ToolType]] = [
        [.selection],
        [.arrow, .line, .rectangle, .ellipse],
        [.freehand],
        [.text, .counter],
        [.mosaic],
    ]

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = Theme.Colors.toolbarBackground.cgColor

        // Main horizontal stack
        let mainStack = NSStackView()
        mainStack.orientation = .horizontal
        mainStack.spacing = 0
        mainStack.alignment = .centerY
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        // Build tool groups with separators
        for (groupIndex, group) in toolGroups.enumerated() {
            if groupIndex > 0 {
                let sep = createSeparator()
                mainStack.addArrangedSubview(sep)
                mainStack.setCustomSpacing(Theme.Dimensions.toolGroupSpacing, after: sep)
            }

            let groupStack = NSStackView()
            groupStack.orientation = .horizontal
            groupStack.spacing = Theme.Dimensions.toolButtonSpacing
            groupStack.alignment = .centerY

            for toolType in group {
                let btn = ToolbarButton(
                    icon: NSImage(systemSymbolName: toolType.icon, accessibilityDescription: toolType.rawValue),
                    toolTip: "\(toolType.rawValue) (\(shortcutKey(for: toolType)))"
                )
                btn.isSelected = toolType == .selection
                btn.onClicked = { [weak self] in
                    self?.selectToolType(toolType)
                }

                let sizeConstraint = NSLayoutConstraint(item: btn, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: Theme.Dimensions.toolButtonSize)
                let heightConstraint = NSLayoutConstraint(item: btn, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: Theme.Dimensions.toolButtonSize)
                btn.addConstraints([sizeConstraint, heightConstraint])

                groupStack.addArrangedSubview(btn)
                toolButtons[toolType] = btn
            }

            mainStack.addArrangedSubview(groupStack)
            if groupIndex < toolGroups.count - 1 {
                mainStack.setCustomSpacing(Theme.Dimensions.toolGroupSpacing, after: groupStack)
            }
        }

        // Right side: separator + color + stroke
        let rightSep = createSeparator()
        mainStack.addArrangedSubview(rightSep)
        mainStack.setCustomSpacing(10, after: rightSep)

        // Color dot button
        colorButton = createColorDot()
        mainStack.addArrangedSubview(colorButton)
        mainStack.setCustomSpacing(10, after: colorButton)

        // Stroke control
        let strokeControl = createStrokeControl()
        mainStack.addArrangedSubview(strokeControl)

        // Layout
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            mainStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
        ])

        // Bottom border
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = Theme.Colors.separator.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    private func createSeparator() -> NSView {
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = Theme.Colors.separator.cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return sep
    }

    private func createColorDot() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: 24).isActive = true
        container.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let dot = ColorDotView(color: currentColor) { [weak self] in
            self?.showColorPicker()
        }
        dot.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dot)
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 20),
            dot.heightAnchor.constraint(equalToConstant: 20),
        ])

        return container
    }

    private func createStrokeControl() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY

        let slider = NSSlider()
        slider.minValue = 1
        slider.maxValue = 10
        slider.doubleValue = 5
        slider.target = self
        slider.action = #selector(strokeChanged(_:))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 70).isActive = true

        let label = NSTextField(labelWithString: "5")
        label.font = Theme.Fonts.strokeValue
        label.textColor = .secondaryLabelColor
        label.tag = 100

        stack.addArrangedSubview(slider)
        stack.addArrangedSubview(label)

        return stack
    }

    private func showColorPicker() {
        let panel = NSColorPanel.shared
        panel.color = currentColor
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.isContinuous = true
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        currentColor = sender.color
        if let dot = colorButton.subviews.first as? ColorDotView {
            dot.color = currentColor
            dot.needsDisplay = true
        }
        delegate?.toolbarDidChangeColor(currentColor)
    }

    @objc private func strokeChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        if let label = sender.superview?.viewWithTag(100) as? NSTextField {
            label.stringValue = String(format: "%.0f", value)
        }
        delegate?.toolbarDidChangeStrokeWidth(value)
    }

    // MARK: - Public

    func selectToolType(_ toolType: ToolType) {
        selectedToolType = toolType
        for (type, btn) in toolButtons {
            btn.isSelected = type == toolType
        }
        delegate?.toolbarDidSelectTool(toolType)
    }

    func selectTool(_ toolType: ToolType) {
        selectToolType(toolType)
    }

    private func shortcutKey(for toolType: ToolType) -> String {
        switch toolType {
        case .selection: return "V"
        case .arrow: return "A"
        case .line: return "L"
        case .rectangle: return "R"
        case .ellipse: return "O"
        case .freehand: return "P"
        case .text: return "T"
        case .counter: return "N"
        case .highlighter: return "H"
        case .blur: return "B"
        case .mosaic: return "M"
        case .spotlight: return "S"
        }
    }
}

// MARK: - Color Dot View

class ColorDotView: NSView {
    var color: NSColor
    var onClick: (() -> Void)?

    init(color: NSColor, onClick: @escaping () -> Void) {
        self.color = color
        self.onClick = onClick
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let dotRect = bounds.insetBy(dx: 2, dy: 2)

        // White border ring
        NSColor.white.withAlphaComponent(0.8).setStroke()
        let outerPath = NSBezierPath(ovalIn: dotRect)
        outerPath.lineWidth = 1.5
        outerPath.stroke()

        // Filled color dot
        color.setFill()
        let innerPath = NSBezierPath(ovalIn: dotRect.insetBy(dx: 1.5, dy: 1.5))
        innerPath.fill()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
