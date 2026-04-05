import AppKit

class TimerOverlay {
    private var window: NSWindow?
    private var countdownLabel: NSTextField?
    private var timer: Timer?
    private var remaining: Int
    private let completionHandler: () -> Void
    private let cancelHandler: () -> Void

    init(countdown: Int, completionHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        self.remaining = countdown
        self.completionHandler = completionHandler
        self.cancelHandler = cancelHandler
    }

    func show() {
        guard let screen = NSScreen.main else { return }

        let size: CGFloat = 160
        let frame = CGRect(
            x: screen.frame.midX - size / 2,
            y: screen.frame.midY - size / 2,
            width: size,
            height: size
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = size / 2

        let label = NSTextField(labelWithString: "\(remaining)")
        label.frame = NSRect(x: 0, y: 40, width: size, height: 80)
        label.alignment = .center
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 64, weight: .bold)
        label.textColor = .white
        bg.addSubview(label)

        window.contentView = bg
        window.makeKeyAndOrderFront(nil)

        self.window = window
        self.countdownLabel = label

        // Start countdown
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        // Play tick sound
        NSSound(named: "Tink")?.play()
    }

    private func tick() {
        remaining -= 1

        if remaining <= 0 {
            timer?.invalidate()
            timer = nil

            // Dismiss window immediately, then wait for it to disappear before capturing
            window?.orderOut(nil)
            window = nil
            // Small delay to ensure the overlay is fully off-screen before capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.completionHandler()
            }
        } else {
            countdownLabel?.stringValue = "\(remaining)"
            NSSound(named: "Tink")?.play()
        }
    }
}
