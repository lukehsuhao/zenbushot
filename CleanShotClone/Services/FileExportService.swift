import AppKit

class FileExportService {
    static func saveImage(_ image: NSImage, defaultName: String? = nil) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["png", "jpg", "jpeg"]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        panel.nameFieldStringValue = defaultName ?? "Screenshot_\(timestamp).png"
        panel.directoryURL = UserSettings.shared.saveDirectory

        panel.level = .floating

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            saveImageToFile(image, url: url)
        }
    }

    static func quickSave(_ image: NSImage) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let saveDir = UserSettings.shared.saveDirectory
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        let fileURL = saveDir.appendingPathComponent("Screenshot_\(timestamp).png")

        saveImageToFile(image, url: fileURL)
    }

    private static func saveImageToFile(_ image: NSImage, url: URL) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

        let data: Data?
        if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg" {
            data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        } else {
            data = bitmapRep.representation(using: .png, properties: [:])
        }

        do {
            try data?.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = L("alert.save.failed")
            alert.informativeText = L("alert.save.failed.msg", error.localizedDescription)
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("alert.ok"))
            alert.runModal()
        }
    }
}
