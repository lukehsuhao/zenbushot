import AppKit

class UserSettings {
    static let shared = UserSettings()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let saveDirectory = "saveDirectory"
        static let playSoundOnCapture = "playSoundOnCapture"
        static let copyToClipboardOnCapture = "copyToClipboardOnCapture"
        static let showFloatingPreview = "showFloatingPreview"
        static let previewDismissDelay = "previewDismissDelay"
        static let defaultColorHex = "defaultColorHex"
        static let defaultStrokeWidth = "defaultStrokeWidth"
        static let previewPosition = "previewPosition"
        static let autoSaveCapture = "autoSaveCapture"
        static let recordAudio = "recordAudio"
        static let audioDeviceUID = "audioDeviceUID"
        static let micGain = "micGain"
        static let overrideSystemShortcuts = "overrideSystemShortcuts"
        static let showRecordingCountdown = "showRecordingCountdown"
    }

    init() {
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.playSoundOnCapture: true,
            Keys.copyToClipboardOnCapture: true,
            Keys.showFloatingPreview: true,
            Keys.previewDismissDelay: 6.0,
            Keys.defaultStrokeWidth: 5.0,
            Keys.previewPosition: "bottomLeft",
            Keys.autoSaveCapture: false,
            Keys.recordAudio: true,
            Keys.micGain: 1.0,
            Keys.showRecordingCountdown: true,
        ])
    }

    // MARK: - Properties

    var saveDirectory: URL {
        get {
            if let path = defaults.string(forKey: Keys.saveDirectory) {
                return URL(fileURLWithPath: path)
            }
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory())
        }
        set { defaults.set(newValue.path, forKey: Keys.saveDirectory) }
    }

    var playSoundOnCapture: Bool {
        get { defaults.bool(forKey: Keys.playSoundOnCapture) }
        set { defaults.set(newValue, forKey: Keys.playSoundOnCapture) }
    }

    var copyToClipboardOnCapture: Bool {
        get { defaults.bool(forKey: Keys.copyToClipboardOnCapture) }
        set { defaults.set(newValue, forKey: Keys.copyToClipboardOnCapture) }
    }

    var showFloatingPreview: Bool {
        get { defaults.bool(forKey: Keys.showFloatingPreview) }
        set { defaults.set(newValue, forKey: Keys.showFloatingPreview) }
    }

    var previewDismissDelay: TimeInterval {
        get { defaults.double(forKey: Keys.previewDismissDelay) }
        set { defaults.set(newValue, forKey: Keys.previewDismissDelay) }
    }

    var defaultStrokeWidth: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.defaultStrokeWidth)) }
        set { defaults.set(Double(newValue), forKey: Keys.defaultStrokeWidth) }
    }

    var defaultAnnotationColor: NSColor {
        get {
            guard let hex = defaults.string(forKey: Keys.defaultColorHex) else { return Theme.Colors.defaultAnnotationColor }
            return NSColor(hex: hex) ?? Theme.Colors.defaultAnnotationColor
        }
        set { defaults.set(newValue.hexString, forKey: Keys.defaultColorHex) }
    }

    var autoSaveCapture: Bool {
        get { defaults.bool(forKey: Keys.autoSaveCapture) }
        set { defaults.set(newValue, forKey: Keys.autoSaveCapture) }
    }

    var recordAudio: Bool {
        get { defaults.bool(forKey: Keys.recordAudio) }
        set { defaults.set(newValue, forKey: Keys.recordAudio) }
    }

    var audioDeviceUID: String {
        get { defaults.string(forKey: Keys.audioDeviceUID) ?? "" }
        set { defaults.set(newValue, forKey: Keys.audioDeviceUID) }
    }

    var micGain: Float {
        get { Float(defaults.double(forKey: Keys.micGain)) }
        set { defaults.set(Double(newValue), forKey: Keys.micGain) }
    }

    var overrideSystemShortcuts: Bool {
        get { defaults.bool(forKey: Keys.overrideSystemShortcuts) }
        set {
            defaults.set(newValue, forKey: Keys.overrideSystemShortcuts)
            SystemShortcutOverride.apply(override: newValue)
        }
    }

    var showRecordingCountdown: Bool {
        get { defaults.bool(forKey: Keys.showRecordingCountdown) }
        set { defaults.set(newValue, forKey: Keys.showRecordingCountdown) }
    }

    var previewPosition: String {
        get { defaults.string(forKey: Keys.previewPosition) ?? "bottomLeft" }
        set { defaults.set(newValue, forKey: Keys.previewPosition) }
    }
}

// MARK: - NSColor hex helpers

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#FF0000" }
        return String(format: "#%02X%02X%02X",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }

    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        guard hexString.count == 6, let hexNum = UInt64(hexString, radix: 16) else { return nil }
        self.init(
            red: CGFloat((hexNum >> 16) & 0xFF) / 255.0,
            green: CGFloat((hexNum >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hexNum & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
