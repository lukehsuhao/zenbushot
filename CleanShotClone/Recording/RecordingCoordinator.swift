import AppKit
import AVFoundation

class RecordingCoordinator {
    static let shared = RecordingCoordinator()

    private var recorder: Any?
    private var controlBar: RecordingControlBar?
    private var isRecording = false
    private var areaOverlay: AreaSelectionOverlay?
    private var countdownOverlay: TimerOverlay?
    private var recordingAreaOverlay: RecordingAreaOverlay?
    private var recordingScreen: NSScreen?
    private var recordingCGRect: CGRect?

    /// Start recording - shows area selection first, then countdown
    func startRecording(fullscreen: Bool) {
        guard !isRecording else { return }

        if fullscreen {
            showCountdown { [weak self] in
                self?.beginRecording(rect: nil)
            }
        } else {
            startAreaSelection()
        }
    }

    /// Let user select an area, then start recording that area
    func startAreaRecording() {
        guard !isRecording else { return }
        startAreaSelection()
    }

    private func startAreaSelection() {
        NSApp.activate(ignoringOtherApps: true)

        let overlay = AreaSelectionOverlay(screens: NSScreen.screens) { [weak self] rect, screen in
            // User selected an area - convert to CG coordinates for ScreenCaptureKit
            guard let self = self else { return }
            self.areaOverlay?.dismiss()
            self.areaOverlay = nil

            // ScreenCaptureKit sourceRect uses display points (origin top-left)
            // rect is in AppKit view coordinates (origin bottom-left)
            let cgRect = CGRect(
                x: rect.origin.x + screen.frame.origin.x,
                y: screen.frame.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )

            self.recordingCGRect = cgRect
            self.recordingScreen = screen

            self.showCountdown { [weak self] in
                // Show dim overlay during recording
                if let screen = self?.recordingScreen {
                    let overlay = RecordingAreaOverlay()
                    overlay.show(rect: cgRect, screen: screen)
                    self?.recordingAreaOverlay = overlay
                }
                self?.beginRecording(rect: cgRect)
            }
        } cancelHandler: { [weak self] in
            self?.areaOverlay?.dismiss()
            self?.areaOverlay = nil
        }
        areaOverlay = overlay
        overlay.show()
    }

    private func showCountdown(completion: @escaping () -> Void) {
        let overlay = TimerOverlay(countdown: 3, completionHandler: { [weak self] in
            self?.countdownOverlay = nil
            completion()
        }, cancelHandler: { [weak self] in
            self?.countdownOverlay = nil
            self?.isRecording = false
        })
        countdownOverlay = overlay
        overlay.show()
    }

    private func beginRecording(rect: CGRect?) {
        isRecording = true

        if #available(macOS 13.0, *) {
            let rec = ScreenRecorder()
            recorder = rec

            rec.onError = { [weak self] error in
                self?.handleError(error)
            }

            let micUID = UserSettings.shared.audioDeviceUID
            rec.startRecording(
                rect: rect,
                includeAudio: UserSettings.shared.recordAudio,
                includeMic: UserSettings.shared.recordAudio,
                micDeviceUID: micUID.isEmpty ? nil : micUID
            ) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success:
                    self.showControlBar()

                case .failure(let error):
                    self.isRecording = false
                    self.recorder = nil

                    let errorMsg = error.localizedDescription
                    let alert = NSAlert()

                    if errorMsg.lowercased().contains("permission") ||
                       errorMsg.lowercased().contains("denied") ||
                       errorMsg.lowercased().contains("not") {
                        alert.messageText = L("alert.recording.permission")
                        alert.informativeText = L("alert.recording.permission.msg")
                    } else {
                        alert.messageText = L("alert.recording.failed")
                        alert.informativeText = "Error: \(errorMsg)"
                    }
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L("alert.open.settings"))
                    alert.addButton(withTitle: L("alert.ok"))
                    if alert.runModal() == .alertFirstButtonReturn {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        controlBar?.dismiss()
        controlBar = nil
        recordingAreaOverlay?.dismiss()
        recordingAreaOverlay = nil

        if #available(macOS 13.0, *) {
            guard let rec = recorder as? ScreenRecorder else { return }

            ProgressHUD.show(message: L("recording.saving"))

            rec.stopRecording { [weak self] url in
                ProgressHUD.dismiss()
                self?.isRecording = false
                self?.recorder = nil

                guard let url = url else { return }
                self?.showSavePanel(for: url)
            }
        }
    }

    private func showControlBar() {
        let bar = RecordingControlBar()
        bar.onStop = { [weak self] in self?.stopRecording() }
        bar.onPauseToggle = { [weak self] isPaused in
            if #available(macOS 13.0, *) {
                if let rec = self?.recorder as? ScreenRecorder {
                    if isPaused { rec.pauseRecording() } else { rec.resumeRecording() }
                }
            }
        }
        bar.show()
        controlBar = bar
    }

    private func showSavePanel(for url: URL) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["mp4", "gif"]
        panel.nameFieldStringValue = "Recording_\(timestamp()).mp4"
        panel.level = .floating

        if panel.runModal() == .OK, let saveURL = panel.url {
            if saveURL.pathExtension == "gif" {
                ProgressHUD.show(message: L("recording.converting.gif"))
                GIFExporter.exportGIF(from: url) { gifURL in
                    ProgressHUD.dismiss()
                    if let gifURL = gifURL {
                        try? FileManager.default.moveItem(at: gifURL, to: saveURL)
                    }
                }
            } else {
                try? FileManager.default.moveItem(at: url, to: saveURL)
            }
        }
    }

    private func handleError(_ error: Error) {
        isRecording = false
        controlBar?.dismiss()
        controlBar = nil
        recorder = nil

        let alert = NSAlert()
        alert.messageText = L("alert.recording.error")
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func timestamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return df.string(from: Date())
    }
}
