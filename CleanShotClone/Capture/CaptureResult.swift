import AppKit

struct CaptureResult {
    let image: NSImage
    let captureRect: CGRect
    let timestamp: Date
    let mode: CaptureMode

    init(image: NSImage, captureRect: CGRect = .zero, mode: CaptureMode) {
        self.image = image
        self.captureRect = captureRect
        self.timestamp = Date()
        self.mode = mode
    }
}

enum CaptureMode {
    case area
    case window
    case fullscreen
    case ocr
    case previousArea
    case timedFullscreen(delay: Int)
    case freezeArea
    case scrollingCapture
}

enum CaptureState {
    case idle
    case selectingArea
    case selectingWindow
    case capturing
    case previewing
    case editing
    case recording
}
