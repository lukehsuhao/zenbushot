import AppKit
import AVFoundation
import ScreenCaptureKit

@available(macOS 13.0, *)
class ScreenRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var micAudioInput: AVAssetWriterInput?
    private var micRecorder: MicrophoneRecorder?
    private var isRecording = false
    private var isPaused = false
    private var sessionStarted = false
    private var outputURL: URL?
    private let writerQueue = DispatchQueue(label: "com.anyshot.writer")
    private var frameCount = 0
    private var micSampleCount = 0

    var onError: ((Error) -> Void)?

    func startRecording(rect: CGRect?, includeAudio: Bool, includeMic: Bool = false, micDeviceUID: String? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                guard let display = content.displays.first else {
                    throw RecordingError.noDisplay
                }

                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

                let config = SCStreamConfiguration()
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.showsCursor = true
                config.pixelFormat = kCVPixelFormatType_32BGRA

                if let rect = rect {
                    config.sourceRect = rect
                    config.width = Int(rect.width) * 2
                    config.height = Int(rect.height) * 2
                } else {
                    config.width = display.width * 2
                    config.height = display.height * 2
                }

                config.width = config.width + (config.width % 2)
                config.height = config.height + (config.height % 2)

                // Setup AVAssetWriter
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "recording_\(Int(Date().timeIntervalSince1970)).mp4"
                let url = tempDir.appendingPathComponent(fileName)
                outputURL = url

                let writer = try AVAssetWriter(url: url, fileType: .mp4)

                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: config.width,
                    AVVideoHeightKey: config.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 12_000_000,
                        AVVideoMaxKeyFrameIntervalKey: 30,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    ] as [String: Any]
                ]
                let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                vInput.expectsMediaDataInRealTime = true
                writer.add(vInput)
                videoInput = vInput

                let pbAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: config.width,
                    kCVPixelBufferHeightKey as String: config.height,
                ]
                pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: vInput,
                    sourcePixelBufferAttributes: pbAttributes
                )

                // Microphone audio input (mono, 48kHz AAC)
                if includeMic {
                    let audioSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 48000,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderBitRateKey: 128_000,
                    ]
                    let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                    aInput.expectsMediaDataInRealTime = true
                    writer.add(aInput)
                    micAudioInput = aInput
                }

                assetWriter = writer
                writer.startWriting()
                frameCount = 0
                micSampleCount = 0

                let scStream = SCStream(filter: filter, configuration: config, delegate: self)
                try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: writerQueue)

                try await scStream.startCapture()
                stream = scStream
                isRecording = true
                sessionStarted = false

                // Start microphone — audio buffers go directly into the AVAssetWriter
                if includeMic {
                    let mic = MicrophoneRecorder()
                    mic.gain = UserSettings.shared.micGain
                    mic.onAudioBuffer = { [weak self] sampleBuffer in
                        self?.writeMicAudio(sampleBuffer)
                    }
                    do {
                        try mic.startRecording(deviceUID: micDeviceUID)
                        self.micRecorder = mic
                        NSLog("[Recording] microphone started")
                    } catch {
                        NSLog("[Recording] microphone failed: \(error) — continuing without mic")
                    }
                }

                NSLog("[Recording] started, mic=\(includeMic), size=\(config.width)x\(config.height)")
                DispatchQueue.main.async { completion(.success(())) }

            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Write microphone audio sample directly to the asset writer
    private func writeMicAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, !isPaused, sessionStarted else { return }
        guard assetWriter?.status == .writing else { return }
        guard micAudioInput?.isReadyForMoreMediaData == true else { return }

        micAudioInput?.append(sampleBuffer)
        micSampleCount += 1
        if micSampleCount <= 3 || micSampleCount % 500 == 0 {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            NSLog("[Recording] mic sample \(micSampleCount): pts=\(pts.seconds)")
        }
    }

    func pauseRecording() {
        isPaused = true
        micRecorder?.pause()
    }
    func resumeRecording() {
        isPaused = false
        micRecorder?.resume()
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else { completion(nil); return }
        isRecording = false

        micRecorder?.stopRecording()
        micRecorder = nil

        Task {
            try? await stream?.stopCapture()
            stream = nil

            NSLog("[Recording] stopping, frames=\(frameCount), micSamples=\(micSampleCount), writer status=\(assetWriter?.status.rawValue ?? -1)")

            videoInput?.markAsFinished()
            micAudioInput?.markAsFinished()

            if let writer = assetWriter, writer.status == .writing {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    writer.finishWriting { cont.resume() }
                }
                NSLog("[Recording] finishWriting done, status=\(writer.status.rawValue)")
            } else {
                NSLog("[Recording] writer not writing: status=\(assetWriter?.status.rawValue ?? -1), error: \(String(describing: assetWriter?.error))")
            }

            DispatchQueue.main.async { [weak self] in
                completion(self?.outputURL)
            }
        }
    }

    // MARK: - SCStreamOutput (video only)

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isRecording, !isPaused, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard assetWriter?.status == .writing else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if !sessionStarted {
            assetWriter?.startSession(atSourceTime: pts)
            sessionStarted = true
            NSLog("[Recording] session started at \(pts.seconds)")
        }

        switch type {
        case .screen:
            guard let adaptor = pixelBufferAdaptor, videoInput?.isReadyForMoreMediaData == true else { return }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let success = adaptor.append(imageBuffer, withPresentationTime: pts)
            frameCount += 1
            if frameCount <= 3 || frameCount % 60 == 0 {
                NSLog("[Recording] video frame \(frameCount): pts=\(pts.seconds), ok=\(success)")
            }

        default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("[Recording] stream error: \(error)")
        DispatchQueue.main.async { [weak self] in self?.onError?(error) }
    }
}

enum RecordingError: LocalizedError {
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display found for recording."
        }
    }
}
