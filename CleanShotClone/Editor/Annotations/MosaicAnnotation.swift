import AppKit
import CoreImage

class MosaicAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var color: NSColor = .clear
    var strokeWidth: CGFloat = 0
    var pixelSize: CGFloat
    private var cachedImage: CGImage?
    private var cachedRect: CGRect = .zero

    init(rect: CGRect, pixelSize: CGFloat = 12) {
        self.boundingRect = rect
        self.pixelSize = pixelSize
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        let rect = boundingRect
        context.setFillColor(NSColor.gray.withAlphaComponent(0.15).cgColor)
        context.fill(rect)

        context.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.stroke(rect)
    }

    func renderMosaic(baseImage: NSImage, in context: CGContext) {
        let rect = boundingRect
        guard rect.width > 0, rect.height > 0 else { return }
        guard let cgBase = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        if cachedRect == rect, let cached = cachedImage {
            context.draw(cached, in: rect)
            return
        }

        let ciImage = CIImage(cgImage: cgBase)
        let imageHeight = CGFloat(cgBase.height)
        let scaleFactor = imageHeight / baseImage.size.height

        let scaledRect = CGRect(
            x: rect.origin.x * scaleFactor,
            y: (baseImage.size.height - rect.origin.y - rect.height) * scaleFactor,
            width: rect.width * scaleFactor,
            height: rect.height * scaleFactor
        )

        let cropped = ciImage.cropped(to: scaledRect)

        // Pixelate using CIPixellate
        guard let pixelFilter = CIFilter(name: "CIPixellate") else { return }
        pixelFilter.setValue(cropped, forKey: kCIInputImageKey)
        pixelFilter.setValue(pixelSize * scaleFactor, forKey: kCIInputScaleKey)
        pixelFilter.setValue(CIVector(x: scaledRect.midX, y: scaledRect.midY), forKey: kCIInputCenterKey)

        guard let output = pixelFilter.outputImage else { return }

        let ciContext = CIContext()
        let clamped = output.cropped(to: scaledRect)
        guard let mosaicCG = ciContext.createCGImage(clamped, from: scaledRect) else { return }

        context.draw(mosaicCG, in: rect)

        cachedImage = mosaicCG
        cachedRect = rect
    }

    func hitTest(_ point: CGPoint) -> Bool {
        boundingRect.contains(point)
    }

    func copy() -> Annotation {
        MosaicAnnotation(rect: boundingRect, pixelSize: pixelSize)
    }

    func invalidateCache() {
        cachedImage = nil
    }
}
