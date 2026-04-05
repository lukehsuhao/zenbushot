import AppKit

class RecordingControlBar {
    private var panel: NSPanel?
    private var timerLabel: NSTextField?
    private var pauseButton: NSButton?
    private var displayTimer: Timer?
    private var recordingStartDate: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartDate: Date?
    private var isPaused = false

    var onStop: (() -> Void)?
    var onPauseToggle: ((Bool) -> Void)?

    func show() {
        guard let screen = NSScreen.main else { return }

        let barWidth: CGFloat = 240
        let barHeight: CGFloat = 44

        let frame = CGRect(
            x: screen.frame.midX - barWidth / 2,
            y: screen.visibleFrame.maxY - barHeight - 12,
            width: barWidth,
            height: barHeight
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = barHeight / 2

        // Recording dot
        let dot = NSView(frame: NSRect(x: 14, y: 16, width: 12, height: 12))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 6
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor

        // Pulse animation
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        dot.layer?.add(pulse, forKey: "pulse")
        bg.addSubview(dot)

        // Timer label
        let label = NSTextField(labelWithString: "00:00")
        label.frame = NSRect(x: 32, y: 12, width: 60, height: 20)
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        bg.addSubview(label)
        timerLabel = label

        // Pause button
        let pauseBtn = NSButton(frame: NSRect(x: 100, y: 8, width: 28, height: 28))
        pauseBtn.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")
        pauseBtn.isBordered = false
        pauseBtn.bezelStyle = .inline
        pauseBtn.contentTintColor = .white
        pauseBtn.target = self
        pauseBtn.action = #selector(togglePause)
        bg.addSubview(pauseBtn)
        pauseButton = pauseBtn

        // Stop button
        let stopBtn = NSButton(frame: NSRect(x: 136, y: 6, width: 32, height: 32))
        stopBtn.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop")
        stopBtn.isBordered = false
        stopBtn.bezelStyle = .inline
        stopBtn.contentTintColor = NSColor.systemRed
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        stopBtn.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop")?.withSymbolConfiguration(config)
        stopBtn.target = self
        stopBtn.action = #selector(stopRecording)
        bg.addSubview(stopBtn)

        panel.contentView = bg
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        recordingStartDate = Date()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }

    func dismiss() {
        displayTimer?.invalidate()
        displayTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func updateTimer() {
        guard let start = recordingStartDate else { return }
        var elapsed = Date().timeIntervalSince(start) - pausedDuration
        if isPaused, let pauseStart = pauseStartDate {
            elapsed -= Date().timeIntervalSince(pauseStart)
        }
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        timerLabel?.stringValue = String(format: "%02d:%02d", minutes, seconds)
    }

    @objc private func togglePause() {
        isPaused.toggle()

        if isPaused {
            pauseStartDate = Date()
            pauseButton?.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Resume")
        } else {
            if let pauseStart = pauseStartDate {
                pausedDuration += Date().timeIntervalSince(pauseStart)
            }
            pauseStartDate = nil
            pauseButton?.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")
        }

        onPauseToggle?(isPaused)
    }

    @objc private func stopRecording() {
        onStop?()
    }
}
