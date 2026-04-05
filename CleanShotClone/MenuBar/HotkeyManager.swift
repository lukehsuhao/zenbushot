import AppKit
import Carbon

class HotkeyManager {
    private weak var coordinator: CaptureCoordinator?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthTimer: Timer?
    private var isPaused = false

    struct ShortcutDef {
        let keyCode: UInt16
        let name: String
        let mode: CaptureMode?
        let isRecord: Bool

        init(_ name: String, keyCode: UInt16, mode: CaptureMode) {
            self.name = name; self.keyCode = keyCode; self.mode = mode; self.isRecord = false
        }
        init(_ name: String, keyCode: UInt16, isRecord: Bool) {
            self.name = name; self.keyCode = keyCode; self.mode = nil; self.isRecord = isRecord
        }
    }

    // All use Cmd+Shift as modifier
    static let shortcuts: [ShortcutDef] = [
        ShortcutDef("Fullscreen Screenshot",  keyCode: 20, mode: .fullscreen),    // Cmd+Shift+3
        ShortcutDef("Area Screenshot",        keyCode: 21, mode: .area),          // Cmd+Shift+4
        ShortcutDef("Window Screenshot",      keyCode: 23, mode: .window),        // Cmd+Shift+5
        ShortcutDef("OCR Capture",            keyCode: 19, mode: .ocr),           // Cmd+Shift+2
        ShortcutDef("Scrolling Capture",      keyCode: 26, mode: .scrollingCapture), // Cmd+Shift+7
        ShortcutDef("Record Area",            keyCode: 28, isRecord: true),       // Cmd+Shift+8
        ShortcutDef("Record Fullscreen",      keyCode: 25, isRecord: true),       // Cmd+Shift+9
    ]

    static var shared: HotkeyManager?

    init(coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
        HotkeyManager.shared = self
        setupEventTap()
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
            guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

            // Re-enable tap if system disabled it
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = mgr.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown, !mgr.isPaused else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            // Check for Cmd+Shift (without other modifiers like Ctrl/Option)
            let isCmdShift = flags.contains([.maskCommand, .maskShift])
                && !flags.contains(.maskControl)
                && !flags.contains(.maskAlternate)

            guard isCmdShift else {
                return Unmanaged.passUnretained(event)
            }

            // Match against our shortcuts
            for shortcut in HotkeyManager.shortcuts {
                if keyCode == shortcut.keyCode {
                    // Fire our action on main thread
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        if shortcut.isRecord {
                            let isFull = shortcut.name.contains("Fullscreen")
                            RecordingCoordinator.shared.startRecording(fullscreen: isFull)
                        } else if let mode = shortcut.mode {
                            CaptureCoordinator.shared.startCapture(mode: mode)
                        }
                    }
                    // Return nil to suppress the event — system never sees it
                    return nil
                }
            }

            return Unmanaged.passUnretained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            NSLog("[HotkeyManager] CGEvent tap creation failed — need Accessibility permission")
            // Prompt for accessibility
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }

        eventTap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Health check — re-enable tap if system disables it
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, let tap = self.eventTap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                NSLog("[HotkeyManager] tap was disabled, re-enabling")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }

        NSLog("[HotkeyManager] CGEvent tap active — intercepting Cmd+Shift shortcuts")
    }

    deinit {
        healthTimer?.invalidate()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}
