import Foundation

/// Localization helper — shorthand for NSLocalizedString
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: L10n.bundle, comment: "")
}

/// Localization helper with format arguments
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: L10n.bundle, comment: ""), arguments: args)
}

enum L10n {
    private static let langKey = "appLanguage"

    /// Supported languages
    static let supportedLanguages: [(code: String, name: String)] = [
        ("", "System Default"),
        ("en", "English"),
        ("zh-Hant", "繁體中文"),
        ("zh-Hans", "简体中文"),
        ("ja", "日本語"),
        ("es", "Español"),
        ("fr", "Français"),
    ]

    /// Current language bundle — reloaded when language changes
    static var bundle: Bundle = loadBundle()

    /// Get the current language code ("" means system default)
    static var currentLanguage: String {
        get { UserDefaults.standard.string(forKey: langKey) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: langKey)
            bundle = loadBundle()
        }
    }

    private static func loadBundle() -> Bundle {
        let saved = UserDefaults.standard.string(forKey: langKey) ?? ""
        let langCode: String
        if saved.isEmpty {
            // System default
            langCode = Locale.preferredLanguages.first ?? "en"
        } else {
            langCode = saved
        }

        // Try exact match first, then prefix match
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let b = Bundle(path: path) {
            return b
        }

        // Try prefix (e.g., "zh-Hant-TW" → "zh-Hant")
        let prefix = String(langCode.prefix(while: { $0 != "-" }))
        for candidate in ["zh-Hant", "zh-Hans", "en", "ja", "es", "fr"] {
            if candidate.hasPrefix(prefix) || langCode.hasPrefix(candidate) {
                if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
                   let b = Bundle(path: path) {
                    return b
                }
            }
        }

        // Fallback to English
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let b = Bundle(path: path) {
            return b
        }

        return Bundle.main
    }
}
