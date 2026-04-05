import AppKit
import CoreImage

class BlurAnnotation: Annotation {
    let id = UUID()
    var boundingRect: CGRect
    var color: NSColor = .clear
    var strokeWidth: CGFloat = 0
    var blurRadius: CGFloat
    private var cachedImage: CGImage?
    private var cachedRect: CGRect = .zero

    init(rect: CGRect, blurRadius: CGFloat = 20) {
        self.boundingRect = rect
        self.blurRadius = blurRadius
    }

    func render(in context: CGContext, canvasSize: CGSize) {
        // We need the base image from the context - blur is applied during final composite
        // For now, draw a semi-transparent overlay to indicate blur region
        let rect = boundingRect

        context.saveGState()
        context.clip(to: rect)

        // Apply pixelation effect as a simpler alternative that works without base image
        // The actual blur will be composited by CanvasView
        context.setFillColor(NSColor.gray.withAlphaComponent(0.15).cgColor)
        context.fill(rect)

        // Draw a subtle border to show the blur region
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.stroke(rect)

        context.restoreGState()
    }

    func renderBlur(baseImage: NSImage, in context: CGContext) {
        let rect = boundingRect
        guard rect.width > 0, rect.height > 0 else { return }

        guard let cgBase = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        // Check cache
        if cachedRect == rect, let cached = cachedImage {
            context.draw(cached, in: rect)
            return
        }

        let ciImage = CIImage(cgImage: cgBase)

        // Crop to region (CIImage has flipped Y)
        let imageHeight = CGFloat(cgBase.height)
        let scaleFactor = imageHeight / baseImage.size.height
        let scaledRect = CGRect(
            x: rect.origin.x * scaleFactor,
            y: (baseImage.size.height - rect.origin.y - rect.height) * scaleFactor,
            width: rect.width * scaleFactor,
            height: rect.height * scaleFactor
        )

        let cropped = ciImage.cropped(to: scaledRect)

        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
        blurFilter.setValue(cropped, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius * scaleFactor, forKey: kCIInputRadiusKey)

        guard let output = blurFilter.outputImage else { return }

        let ciContext = CIContext()
        // Clamp to avoid edge artifacts
        let clamped = output.cropped(to: scaledRect)
        guard let blurredCG = ciContext.createCGImage(clamped, from: scaledRect) else { return }

        context.draw(blurredCG, in: rect)

        cachedImage = blurredCG
        cachedRect = rect
    }

    func hitTest(_ point: CGPoint) -> Bool {
        boundingRect.contains(point)
    }

    func copy() -> Annotation {
        BlurAnnotation(rect: boundingRect, blurRadius: blurRadius)
    }

    func invalidateCache() {
        cachedImage = nil
    }
}
