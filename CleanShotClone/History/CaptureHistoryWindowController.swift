import AppKit

class CaptureHistoryWindowController: NSWindowController {
    private static var instance: CaptureHistoryWindowController?
    private var items: [CaptureHistoryItem] = []
    private var scrollView: NSScrollView!
    private var gridView: NSView!

    static func show() {
        if let existing = instance {
            existing.window?.makeKeyAndOrderFront(nil)
            existing.reload()
            return
        }
        let ctrl = CaptureHistoryWindowController()
        instance = ctrl
        ctrl.showWindow(nil)
    }

    init() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Capture History"
        window.center()
        window.minSize = NSSize(width: 400, height: 300)

        super.init(window: window)
        window.delegate = self
        setupUI()
        reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Top bar
        let topBar = NSView(frame: CGRect(x: 0, y: contentView.bounds.height - 40, width: contentView.bounds.width, height: 40))
        topBar.autoresizingMask = [.width, .minYMargin]
        topBar.wantsLayer = true

        let countLabel = NSTextField(labelWithString: "")
        countLabel.frame = CGRect(x: 12, y: 10, width: 200, height: 20)
        countLabel.font = Theme.Fonts.label
        countLabel.textColor = .secondaryLabelColor
        countLabel.tag = 300
        topBar.addSubview(countLabel)

        let clearBtn = NSButton(title: "Clear All", target: self, action: #selector(clearAll))
        clearBtn.frame = CGRect(x: contentView.bounds.width - 90, y: 8, width: 78, height: 24)
        clearBtn.bezelStyle = .rounded
        clearBtn.controlSize = .small
        clearBtn.autoresizingMask = [.minXMargin]
        topBar.addSubview(clearBtn)

        contentView.addSubview(topBar)

        // Scroll view for grid
        scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: contentView.bounds.width, height: contentView.bounds.height - 40))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.Colors.canvasBackground

        gridView = NSView(frame: scrollView.bounds)
        scrollView.documentView = gridView

        contentView.addSubview(scrollView)
    }

    func reload() {
        items = CaptureHistoryStore.shared.loadAll()

        // Update count label
        if let topBar = window?.contentView?.subviews.last,
           let label = topBar.viewWithTag(300) as? NSTextField {
            label.stringValue = "\(items.count) captures"
        }

        // Rebuild grid
        gridView.subviews.removeAll()

        let columns = 4
        let spacing: CGFloat = 8
        let scrollWidth = scrollView.bounds.width
        let cellWidth = (scrollWidth - spacing * CGFloat(columns + 1)) / CGFloat(columns)
        let cellHeight = cellWidth * 0.7

        let rows = Int(ceil(Double(items.count) / Double(columns)))
        let totalHeight = max(CGFloat(rows) * (cellHeight + spacing) + spacing, scrollView.bounds.height)
        gridView.frame = NSRect(x: 0, y: 0, width: scrollWidth, height: totalHeight)

        for (i, item) in items.enumerated() {
            let col = i % columns
            let row = i / columns

            let x = spacing + CGFloat(col) * (cellWidth + spacing)
            let y = totalHeight - spacing - CGFloat(row + 1) * (cellHeight + spacing)

            let cellView = HistoryCellView(
                frame: NSRect(x: x, y: y, width: cellWidth, height: cellHeight),
                item: item,
                index: i
            )
            cellView.onAction = { [weak self] action, idx in
                self?.handleCellAction(action, at: idx)
            }
            gridView.addSubview(cellView)
        }
    }

    private func handleCellAction(_ action: String, at index: Int) {
        guard index < items.count else { return }
        let item = items[index]

        switch action {
        case "open":
            if let image = CaptureHistoryStore.shared.loadImage(for: item) {
                let result = CaptureResult(image: image, mode: .area)
                let editor = EditorWindowController(result: result)
                editor.showWindow(nil)
            }
        case "copy":
            if let image = CaptureHistoryStore.shared.loadImage(for: item) {
                ClipboardService.copyImage(image)
            }
        case "delete":
            CaptureHistoryStore.shared.delete(id: item.id)
            reload()
        default:
            break
        }
    }

    @objc private func clearAll() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This will permanently delete all captured screenshots from history."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            CaptureHistoryStore.shared.clearAll()
            reload()
        }
    }
}

extension CaptureHistoryWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        CaptureHistoryWindowController.instance = nil
    }
}

// MARK: - History Cell View

class HistoryCellView: NSView {
    var onAction: ((String, Int) -> Void)?
    private let index: Int

    init(frame: NSRect, item: CaptureHistoryItem, index: Int) {
        self.index = index
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor

        // Thumbnail
        let imageView = NSImageView(frame: NSRect(x: 4, y: 24, width: frame.width - 8, height: frame.height - 28))
        imageView.image = CaptureHistoryStore.shared.loadThumbnail(for: item)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)

        // Date label
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd HH:mm"
        let dateLabel = NSTextField(labelWithString: dateFormatter.string(from: item.timestamp))
        dateLabel.frame = NSRect(x: 4, y: 4, width: frame.width - 8, height: 16)
        dateLabel.font = NSFont.systemFont(ofSize: 9)
        dateLabel.textColor = .secondaryLabelColor
        addSubview(dateLabel)

        // Context menu
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open in Editor", action: #selector(openClicked), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let copyItem = NSMenuItem(title: "Copy", action: #selector(copyClicked), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteClicked), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        self.menu = menu
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onAction?("open", index)
        }
    }

    @objc private func openClicked() { onAction?("open", index) }
    @objc private func copyClicked() { onAction?("copy", index) }
    @objc private func deleteClicked() { onAction?("delete", index) }
}
