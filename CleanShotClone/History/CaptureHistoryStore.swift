import AppKit

struct CaptureHistoryItem: Codable {
    let id: String
    let timestamp: Date
    let mode: String
    let imagePath: String
    let thumbnailPath: String
}

class CaptureHistoryStore {
    static let shared = CaptureHistoryStore()

    private let baseDir: URL
    private let capturesDir: URL
    private let metadataURL: URL
    private let maxItems = 100

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDir = appSupport.appendingPathComponent("ZenbuShot")
        capturesDir = baseDir.appendingPathComponent("captures")
        metadataURL = baseDir.appendingPathComponent("history.json")

        try? FileManager.default.createDirectory(at: capturesDir, withIntermediateDirectories: true)
    }

    func save(result: CaptureResult) {
        let id = UUID().uuidString
        let imagePath = capturesDir.appendingPathComponent("\(id).png")
        let thumbPath = capturesDir.appendingPathComponent("\(id)_thumb.png")

        // Save full image
        guard let cgImage = result.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: imagePath)

        // Generate and save thumbnail
        let thumbSize: CGFloat = 200
        let imageSize = result.image.size
        let scale = min(thumbSize / imageSize.width, thumbSize / imageSize.height, 1.0)
        let thumbDimension = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        let thumbImage = NSImage(size: thumbDimension)
        thumbImage.lockFocus()
        result.image.draw(in: CGRect(origin: .zero, size: thumbDimension),
                          from: CGRect(origin: .zero, size: imageSize),
                          operation: .sourceOver, fraction: 1.0)
        thumbImage.unlockFocus()

        if let thumbCG = thumbImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let thumbRep = NSBitmapImageRep(cgImage: thumbCG)
            if let thumbData = thumbRep.representation(using: .png, properties: [:]) {
                try? thumbData.write(to: thumbPath)
            }
        }

        // Save metadata
        var modeString: String
        switch result.mode {
        case .area: modeString = "area"
        case .window: modeString = "window"
        case .fullscreen: modeString = "fullscreen"
        case .ocr: modeString = "ocr"
        default: modeString = "other"
        }

        let item = CaptureHistoryItem(
            id: id,
            timestamp: result.timestamp,
            mode: modeString,
            imagePath: imagePath.path,
            thumbnailPath: thumbPath.path
        )

        var items = loadAll()
        items.insert(item, at: 0)

        // Trim to max
        if items.count > maxItems {
            let removed = items[maxItems...]
            for old in removed {
                try? FileManager.default.removeItem(atPath: old.imagePath)
                try? FileManager.default.removeItem(atPath: old.thumbnailPath)
            }
            items = Array(items.prefix(maxItems))
        }

        saveMetadata(items)
    }

    func loadAll() -> [CaptureHistoryItem] {
        guard let data = try? Data(contentsOf: metadataURL),
              let items = try? JSONDecoder().decode([CaptureHistoryItem].self, from: data) else {
            return []
        }
        return items
    }

    func delete(id: String) {
        var items = loadAll()
        if let item = items.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(atPath: item.imagePath)
            try? FileManager.default.removeItem(atPath: item.thumbnailPath)
        }
        items.removeAll { $0.id == id }
        saveMetadata(items)
    }

    func clearAll() {
        let items = loadAll()
        for item in items {
            try? FileManager.default.removeItem(atPath: item.imagePath)
            try? FileManager.default.removeItem(atPath: item.thumbnailPath)
        }
        saveMetadata([])
    }

    func loadImage(for item: CaptureHistoryItem) -> NSImage? {
        NSImage(contentsOfFile: item.imagePath)
    }

    func loadThumbnail(for item: CaptureHistoryItem) -> NSImage? {
        NSImage(contentsOfFile: item.thumbnailPath)
    }

    private func saveMetadata(_ items: [CaptureHistoryItem]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(items) {
            try? data.write(to: metadataURL)
        }
    }
}
