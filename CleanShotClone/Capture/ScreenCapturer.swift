import AppKit
import CoreGraphics

class ScreenCapturer {

    /// Capture the entire main screen
    static func captureFullscreen() -> NSImage? {
        guard let mainDisplay = NSScreen.main else { return nil }
        let displayID = mainDisplay.displayID

        guard let cgImage = CGDisplayCreateImage(displayID) else { return nil }

        return NSImage(cgImage: cgImage, size: mainDisplay.frame.size)
    }

    /// Capture all screens combined
    static func captureAllScreens() -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else { return nil }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Capture a specific rect on screen
    static func captureRect(_ rect: CGRect) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else { return nil }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Capture a specific window by ID
    static func captureWindow(windowID: CGWindowID) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return nil }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Live capture of a specific rect on a screen (for scrolling capture)
    /// Uses CGDisplayCreateImage + crop to avoid coordinate issues during scroll
    static func captureDisplayRect(_ rect: CGRect, on screen: NSScreen) -> CGImage? {
        let displayID = screen.displayID
        guard let fullImage = CGDisplayCreateImage(displayID) else { return nil }

        let scale = CGFloat(fullImage.width) / screen.frame.width
        let flippedY = screen.frame.height - rect.origin.y - rect.height

        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: flippedY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        return fullImage.cropping(to: cropRect)
    }

    /// Capture a specific NSScreen
    static func captureScreen(_ screen: NSScreen) -> NSImage? {
        let displayID = screen.displayID
        guard let cgImage = CGDisplayCreateImage(displayID) else { return nil }
        return NSImage(cgImage: cgImage, size: screen.frame.size)
    }
}

// MARK: - NSScreen extension to get display ID
extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
