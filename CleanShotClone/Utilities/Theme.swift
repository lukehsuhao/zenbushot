import AppKit

enum Theme {
    // MARK: - Colors
    enum Colors {
        static let canvasBackground = NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        static let toolbarBackground = NSColor.windowBackgroundColor
        static let buttonHover = NSColor.white.withAlphaComponent(0.08)
        static let buttonSelected = NSColor.controlAccentColor.withAlphaComponent(0.15)
        static let buttonSelectedTint = NSColor.controlAccentColor
        static let accentBlue = NSColor.systemBlue
        static let surfacePrimary = NSColor.windowBackgroundColor
        static let surfaceSecondary = NSColor.controlBackgroundColor
        static let separator = NSColor.separatorColor
        static let overlayDim = NSColor.black.withAlphaComponent(0.3)
        static let labelPill = NSColor.black.withAlphaComponent(0.8)
        static let defaultAnnotationColor = NSColor.systemRed
        static let defaultStrokeWidth: CGFloat = 5
        static let highlighterDefault = NSColor.systemYellow
    }

    // MARK: - Dimensions
    enum Dimensions {
        static let toolbarHeight: CGFloat = 44
        static let bottomBarHeight: CGFloat = 44
        static let toolButtonSize: CGFloat = 28
        static let toolButtonSpacing: CGFloat = 1
        static let toolGroupSpacing: CGFloat = 8
        static let cornerRadius: CGFloat = 6
        static let handleSize: CGFloat = 8
        static let selectionTolerance: CGFloat = 8
        static let minAnnotationSize: CGFloat = 5

        // Preview window
        static let previewWidth: CGFloat = 300
        static let previewHeight: CGFloat = 220
        static let previewMargin: CGFloat = 16
        static let previewCornerRadius: CGFloat = 12
        static let previewDismissDelay: TimeInterval = 6.0

        // Editor window
        static let editorMaxWidth: CGFloat = 1200
        static let editorMaxHeight: CGFloat = 800
        static let editorMinWidth: CGFloat = 500
        static let editorMinHeight: CGFloat = 300

        // HUD
        static let hudWidth: CGFloat = 200
        static let hudHeight: CGFloat = 80
        static let hudCornerRadius: CGFloat = 12

        // Timer
        static let timerSize: CGFloat = 160

        // Magnifier
        static let magnifierSize: CGFloat = 120
        static let magnifierZoom: CGFloat = 4

        // Area selection
        static let overlayDimOpacity: CGFloat = 0.3
        static let dimensionFontSize: CGFloat = 12
        static let dimensionPadding: CGFloat = 8
        static let dimensionPillRadius: CGFloat = 6

        // Pinned window
        static let pinnedMaxDimension: CGFloat = 400
    }

    // MARK: - Fonts
    enum Fonts {
        static let toolbar = NSFont.systemFont(ofSize: 11)
        static let label = NSFont.systemFont(ofSize: 11)
        static let dimensionLabel = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        static let hudLabel = NSFont.systemFont(ofSize: 12)
        static let timerCountdown = NSFont.monospacedDigitSystemFont(ofSize: 64, weight: .bold)
        static let coordinateLabel = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        static let strokeValue = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    }

    // MARK: - Animation
    enum Animation {
        static let buttonPress: TimeInterval = 0.1
        static let hoverTransition: TimeInterval = 0.15
        static let slideIn: TimeInterval = 0.3
        static let fadeOut: TimeInterval = 0.2
        static let buttonBarReveal: TimeInterval = 0.15
    }
}
