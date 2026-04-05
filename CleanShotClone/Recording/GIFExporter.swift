import AppKit
import AVFoundation
import ImageIO

class GIFExporter {
    static func exportGIF(from videoURL: URL, fps: Int = 15, maxWidth: CGFloat = 640, completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: videoURL)
            guard let track = asset.tracks(withMediaType: .video).first else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let duration = CMTimeGetSeconds(asset.duration)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            // Scale down if needed
            let naturalSize = track.naturalSize
            let scale = min(maxWidth / naturalSize.width, 1.0)
            generator.maximumSize = CGSize(width: naturalSize.width * scale, height: naturalSize.height * scale)

            let frameCount = Int(duration * Double(fps))
            guard frameCount > 0 else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Create GIF
            let tempDir = FileManager.default.temporaryDirectory
            let gifURL = tempDir.appendingPathComponent("recording_\(Int(Date().timeIntervalSince1970)).gif")

            guard let destination = CGImageDestinationCreateWithURL(gifURL as CFURL, kUTTypeGIF, frameCount, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let gifProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: 0
                ]
            ]
            CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

            let frameDelay = 1.0 / Double(fps)
            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: frameDelay
                ]
            ]

            for i in 0..<frameCount {
                let time = CMTime(seconds: Double(i) * frameDelay, preferredTimescale: 600)
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                } catch {
                    continue
                }
            }

            if CGImageDestinationFinalize(destination) {
                DispatchQueue.main.async { completion(gifURL) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
