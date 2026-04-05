import AVFoundation
import AudioToolbox
import CoreAudio

/// Records microphone audio using Audio Queue Services (Core Audio).
/// Delivers raw audio buffers via a callback for direct writing to AVAssetWriter.
class MicrophoneRecorder {
    private var audioQueue: AudioQueueRef?
    private var isRunning = false
    private var isPaused = false
    private var sampleRate: Float64 = 48000
    private var sampleCount: Int64 = 0

    /// Microphone gain (1.0 = no change, 0.5 = quieter, 2.0 = louder)
    var gain: Float = 1.0

    /// Called for each audio buffer received from the microphone
    var onAudioBuffer: ((CMSampleBuffer) -> Void)?

    static func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default: completion(false)
        }
    }

    static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func startRecording(deviceUID: String? = nil) throws {
        sampleRate = 48000
        sampleCount = 0

        // Mono Float32 PCM at 48kHz
        var format = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var queue: AudioQueueRef?
        var status = AudioQueueNewInput(&format, audioQueueCallback, selfPtr, nil, nil, 0, &queue)
        guard status == noErr, let aq = queue else {
            throw MicrophoneError.noInputAvailable
        }
        audioQueue = aq

        // Set input device
        if let uid = deviceUID, !uid.isEmpty {
            var cfUID = uid as CFString
            AudioQueueSetProperty(aq, kAudioQueueProperty_CurrentDevice, &cfUID, UInt32(MemoryLayout<CFString>.size))
            NSLog("[MicrophoneRecorder] set device: \(uid)")
        }

        // Allocate buffers (100ms each, 3 buffers)
        let bufferSize: UInt32 = UInt32(sampleRate) * 4 / 10
        for _ in 0..<3 {
            var buffer: AudioQueueBufferRef?
            AudioQueueAllocateBuffer(aq, bufferSize, &buffer)
            if let buf = buffer {
                AudioQueueEnqueueBuffer(aq, buf, 0, nil)
            }
        }

        status = AudioQueueStart(aq, nil)
        guard status == noErr else {
            AudioQueueDispose(aq, true)
            throw MicrophoneError.noInputAvailable
        }

        isRunning = true
        NSLog("[MicrophoneRecorder] started, device=\(deviceUID ?? "default")")
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    func stopRecording() {
        guard isRunning else { return }
        isRunning = false
        if let aq = audioQueue {
            AudioQueueStop(aq, true)
            AudioQueueDispose(aq, true)
        }
        audioQueue = nil
        onAudioBuffer = nil
        NSLog("[MicrophoneRecorder] stopped, total samples=\(sampleCount)")
    }

    // MARK: - Audio Queue Callback

    fileprivate func handleBuffer(_ buffer: AudioQueueBufferRef, _ packetCount: UInt32) {
        guard isRunning, !isPaused else {
            if let aq = audioQueue { AudioQueueEnqueueBuffer(aq, buffer, 0, nil) }
            return
        }

        let frameCount = Int(packetCount)
        guard frameCount > 0 else {
            if let aq = audioQueue { AudioQueueEnqueueBuffer(aq, buffer, 0, nil) }
            return
        }

        // Apply gain to Float32 samples
        if gain != 1.0 {
            let ptr = buffer.pointee.mAudioData.bindMemory(to: Float32.self, capacity: frameCount)
            for i in 0..<frameCount {
                ptr[i] = min(1.0, max(-1.0, ptr[i] * gain))
            }
        }

        // Create CMSampleBuffer from the raw audio data
        if let sampleBuffer = createSampleBuffer(from: buffer, frameCount: frameCount) {
            onAudioBuffer?(sampleBuffer)
            sampleCount += Int64(frameCount)
        }

        // Re-enqueue
        if let aq = audioQueue {
            AudioQueueEnqueueBuffer(aq, buffer, 0, nil)
        }
    }

    private func createSampleBuffer(from buffer: AudioQueueBufferRef, frameCount: Int) -> CMSampleBuffer? {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        var formatDesc: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd,
                                        layoutSize: 0, layout: nil,
                                        magicCookieSize: 0, magicCookie: nil,
                                        extensions: nil, formatDescriptionOut: &formatDesc)
        guard let desc = formatDesc else { return nil }

        let dataSize = Int(buffer.pointee.mAudioDataByteSize)
        var blockBuffer: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: dataSize,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataSize,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard let block = blockBuffer else { return nil }

        CMBlockBufferReplaceDataBytes(
            with: buffer.pointee.mAudioData,
            blockBuffer: block,
            offsetIntoDestination: 0,
            dataLength: dataSize
        )

        let pts = CMTimeMake(value: sampleCount, timescale: Int32(sampleRate))
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: Int64(frameCount), timescale: Int32(sampleRate)),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            dataReady: true,
            makeDataReadyCallback: nil, refcon: nil,
            formatDescription: desc,
            sampleCount: frameCount,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 0, sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        return sampleBuffer
    }
}

private func audioQueueCallback(
    _ userData: UnsafeMutableRawPointer?,
    _ queue: AudioQueueRef,
    _ buffer: AudioQueueBufferRef,
    _ startTime: UnsafePointer<AudioTimeStamp>,
    _ packetCount: UInt32,
    _ packetDescs: UnsafePointer<AudioStreamPacketDescription>?
) {
    guard let ptr = userData else { return }
    let recorder = Unmanaged<MicrophoneRecorder>.fromOpaque(ptr).takeUnretainedValue()
    recorder.handleBuffer(buffer, packetCount)
}

enum MicrophoneError: LocalizedError {
    case noInputAvailable
    case permissionDenied
    var errorDescription: String? {
        switch self {
        case .noInputAvailable: return "No microphone input available."
        case .permissionDenied: return "Microphone permission denied."
        }
    }
}
