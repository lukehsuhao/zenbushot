import AppKit

class ScrollingCaptureCoordinator {
    private var captureRect: CGRect = .zero
    private var captureScreen: NSScreen?
    private var frames: [CGImage] = []
    private var areaOverlay: AreaSelectionOverlay?
    private var controlBar: ScrollingCaptureControlBar?
    private var highlight: ScrollingCaptureHighlight?
    private var scrollMonitor: ScrollEventMonitor?
    private var autoScrollTimer: Timer?
    private var isCapturing = false
    private var isAutoScrolling = false
    private var identicalCount = 0
    private var escMonitor: Any?
    private var globalEscMonitor: Any?
    private var previousApp: NSRunningApplication?

    var onComplete: ((NSImage) -> Void)?
    var onCancel: (() -> Void)?

    func startAreaSelection() {
        NSApp.activate(ignoringOtherApps: true)

        let overlay = AreaSelectionOverlay(screens: NSScreen.screens) { [weak self] rect, screen in
            self?.areaSelected(rect: rect, screen: screen)
        } cancelHandler: { [weak self] in
            self?.cancel()
        }
        areaOverlay = overlay
        overlay.show()
    }

    private func areaSelected(rect: CGRect, screen: NSScreen) {
        previousApp = NSWorkspace.shared.frontmostApplication

        areaOverlay?.dismiss()
        areaOverlay = nil

        captureRect = rect
        captureScreen = screen

        highlight = ScrollingCaptureHighlight()
        highlight?.show(rect: rect, on: screen)

        controlBar = ScrollingCaptureControlBar()
        controlBar?.show(above: rect, screen: screen)

        controlBar?.onStart = { [weak self] in self?.startCapturing(autoScroll: false) }
        controlBar?.onAutoScroll = { [weak self] in self?.startCapturing(autoScroll: true) }
        controlBar?.onCancel = { [weak self] in self?.cancel() }
        controlBar?.onDone = { [weak self] in self?.finishCapture() }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.cancel(); return nil }
            return event
        }
        globalEscMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.cancel() }
        }
    }

    private func startCapturing(autoScroll: Bool) {
        isCapturing = true
        isAutoScrolling = autoScroll
        identicalCount = 0
        frames.removeAll()

        // Focus back to the browser (don't move mouse)
        if let prevApp = previousApp {
            prevApp.activate()
        }

        // Switch UI to capturing mode immediately, then capture first frame after delay
        controlBar?.showCapturingMode(frameCount: 0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.doCapture()

            if autoScroll {
                self.autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
                    self?.autoScrollStep()
                }
            } else {
                self.scrollMonitor = ScrollEventMonitor()
                self.scrollMonitor?.onScrollSettled = { [weak self] in
                    self?.doCapture()
                }
                self.scrollMonitor?.start()
            }
        }
    }

    /// Capture a frame: hide highlight, capture, re-show highlight
    private func doCapture() {
        guard isCapturing else {
            NSLog("[ScrollCapture] doCapture: not capturing, skip")
            return
        }
        guard let screen = captureScreen else {
            NSLog("[ScrollCapture] doCapture: no captureScreen, skip")
            return
        }

        NSLog("[ScrollCapture] doCapture called, rect=\(captureRect), screen=\(screen.frame)")

        // Hide highlight so it doesn't appear in capture (hide, not dismiss — keep the window)
        highlight?.hide()

        // Use async to let the window actually disappear from screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self = self else {
                NSLog("[ScrollCapture] doCapture async: self is nil")
                return
            }
            guard self.isCapturing else {
                NSLog("[ScrollCapture] doCapture async: no longer capturing")
                return
            }
            guard let screen = self.captureScreen else {
                NSLog("[ScrollCapture] doCapture async: captureScreen is nil")
                return
            }

            let frame = ScreenCapturer.captureDisplayRect(self.captureRect, on: screen)

            // Re-show highlight (reuses existing window)
            self.highlight?.show(rect: self.captureRect, on: screen)

            guard let frame = frame else {
                NSLog("[ScrollCapture] doCapture: captureDisplayRect returned nil!")
                return
            }

            NSLog("[ScrollCapture] captured frame: \(frame.width)x\(frame.height)")

            // Check identical (page reached bottom)
            if let last = self.frames.last, ScrollCaptureStitcher.framesIdentical(last, frame) {
                self.identicalCount += 1
                NSLog("[ScrollCapture] frame identical (count=\(self.identicalCount))")
                return
            }

            self.identicalCount = 0
            self.frames.append(frame)
            NSLog("[ScrollCapture] frame added, total=\(self.frames.count)")
            self.controlBar?.updateFrameCount(self.frames.count)
        }
    }

    private func autoScrollStep() {
        guard isCapturing else { return }

        if identicalCount >= 2 {
            finishCapture()
            return
        }

        // Move mouse to center of capture rect so scroll events target the right window
        let screenFrame = captureScreen?.frame ?? .zero
        let centerX = captureRect.origin.x + screenFrame.origin.x + captureRect.width / 2
        let centerY = captureRect.origin.y + screenFrame.origin.y + captureRect.height / 2
        // CGEvent uses top-left origin, NSScreen uses bottom-left
        let mainH = NSScreen.screens.map { $0.frame.maxY }.max() ?? 1080
        let cgY = mainH - centerY

        if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                     mouseCursorPosition: CGPoint(x: centerX, y: cgY), mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
        }

        // Post scroll using pixel units for more reliable scrolling
        ScrollEventMonitor.postScroll(deltaY: -300)

        NSLog("[ScrollCapture] autoScroll: posted scroll, mouse at (\(centerX), \(cgY))")

        // Wait for render, then capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self = self, self.isCapturing else { return }
            self.doCapture()

            // Check after capture (with delay for async doCapture)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.identicalCount >= 2 {
                    self.finishCapture()
                }
            }
        }
    }

    private func finishCapture() {
        NSLog("[ScrollCapture] finishCapture: isCapturing=\(isCapturing), frames=\(frames.count)")
        guard isCapturing || !frames.isEmpty else {
            NSLog("[ScrollCapture] finishCapture: nothing to finish, cancelling")
            cancel()
            return
        }
        stopCapturing()

        let capturedFrames = frames
        let completeHandler = onComplete
        let cancelHandler = onCancel

        guard !capturedFrames.isEmpty else {
            cleanup()
            cancelHandler?()
            return
        }

        ProgressHUD.show(message: "Stitching \(capturedFrames.count) frames...")

        DispatchQueue.global(qos: .userInitiated).async {
            let result = ScrollCaptureStitcher.stitch(frames: capturedFrames)

            DispatchQueue.main.async { [weak self] in
                ProgressHUD.dismiss()
                self?.cleanup()

                if let image = result {
                    completeHandler?(image)
                } else {
                    // Stitch failed — fallback to first frame so user doesn't lose capture
                    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                    if let first = capturedFrames.first {
                        let size = NSSize(width: CGFloat(first.width) / scale,
                                          height: CGFloat(first.height) / scale)
                        completeHandler?(NSImage(cgImage: first, size: size))
                    } else {
                        cancelHandler?()
                    }
                }
            }
        }
    }

    private func cancel() {
        stopCapturing()
        cleanup()
        onCancel?()
    }

    private func stopCapturing() {
        isCapturing = false
        isAutoScrolling = false
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        scrollMonitor?.stop()
        scrollMonitor = nil
    }

    private func cleanup() {
        areaOverlay?.dismiss()
        areaOverlay = nil
        controlBar?.dismiss()
        controlBar = nil
        highlight?.dismiss()
        highlight = nil
        if let m = escMonitor { NSEvent.removeMonitor(m) }
        if let m = globalEscMonitor { NSEvent.removeMonitor(m) }
        escMonitor = nil
        globalEscMonitor = nil
        frames.removeAll()
    }
}
