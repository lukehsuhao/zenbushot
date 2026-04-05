import AppKit

extension NSImage {
    /// Crop image to a specific rect
    func cropped(to rect: CGRect) -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let scaleFactor = CGFloat(cgImage.width) / size.width
        let scaledRect = CGRect(
            x: rect.origin.x * scaleFactor,
            y: (size.height - rect.origin.y - rect.height) * scaleFactor,
            width: rect.width * scaleFactor,
            height: rect.height * scaleFactor
        )

        guard let cropped = cgImage.cropping(to: scaledRect) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }
}
