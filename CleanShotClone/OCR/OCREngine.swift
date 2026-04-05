import AppKit
import Vision

class OCREngine {
    static let shared = OCREngine()

    /// Recognizes text in the given image. Completion is always called on the main thread.
    func recognizeText(in image: NSImage, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            let result: Result<[String], Error>

            if let error = error {
                result = .failure(error)
            } else {
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let texts = observations.compactMap { $0.topCandidates(1).first?.string }
                result = .success(texts)
            }

            DispatchQueue.main.async { completion(result) }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en", "ja"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image for text recognition."
        }
    }
}
