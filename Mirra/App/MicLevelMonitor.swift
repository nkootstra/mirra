import AVFoundation
import Combine

/// Monitors microphone audio levels for the notch preview.
/// Uses a separate AVCaptureSession to avoid interfering with the camera session.
/// Only captures while actively monitoring — call startMonitoring()/stopMonitoring().
@MainActor
final class MicLevelService: NSObject, ObservableObject {
    @Published var isAvailable: Bool = false
    @Published var level: Float = 0  // 0.0 (silence) to 1.0 (max)
    @Published var isMonitoring: Bool = false

    private var audioSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private let audioQueue = DispatchQueue(label: "com.mirra.micLevel")

    /// Check whether any microphone is available (lightweight, no capture).
    func check() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        isAvailable = !devices.isEmpty
    }

    /// Start capturing audio levels. The mic level updates at ~15 Hz.
    func startMonitoring() {
        check()
        guard isAvailable else { return }
        guard !isMonitoring else { return }

        let session = AVCaptureSession()

        guard let mic = AVCaptureDevice.default(for: .audio) else {
            isAvailable = false
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: mic)
            guard session.canAddInput(input) else { return }
            session.addInput(input)
        } catch {
            isAvailable = false
            return
        }

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: audioQueue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        audioSession = session
        audioOutput = output
        isMonitoring = true

        audioQueue.async { session.startRunning() }
    }

    /// Stop capturing audio levels.
    func stopMonitoring() {
        let session = audioSession
        audioQueue.async { session?.stopRunning() }
        audioSession = nil
        audioOutput = nil
        isMonitoring = false
        level = 0
    }
}

// MARK: - Audio sample buffer processing

extension MicLevelService: AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let channelData = extractAveragePower(from: sampleBuffer) else { return }

        // Convert dB (-160...0) to linear 0...1
        // -50 dB is effectively silence for UI purposes
        let minDB: Float = -50
        let clampedDB = max(channelData, minDB)
        let normalized = (clampedDB - minDB) / (0 - minDB)

        Task { @MainActor in
            self.level = normalized
        }
    }

    /// Extract average power in dB from an audio sample buffer.
    nonisolated private func extractAveragePower(from buffer: CMSampleBuffer) -> Float? {
        guard let format = CMSampleBufferGetFormatDescription(buffer) else { return nil }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        guard let desc = asbd?.pointee else { return nil }

        guard desc.mFormatID == kAudioFormatLinearPCM else { return nil }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { return nil }
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength, dataPointerOut: &dataPointer
        )
        guard status == noErr, let data = dataPointer else { return nil }

        let isFloat = desc.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let bytesPerSample = Int(desc.mBitsPerChannel / 8)
        let channelCount = Int(desc.mChannelsPerFrame)
        let bytesPerFrame = bytesPerSample * channelCount
        let frameCount = totalLength / bytesPerFrame
        guard frameCount > 0 else { return nil }

        var sum: Float = 0
        let raw = UnsafeRawPointer(data)

        if isFloat && bytesPerSample == 4 {
            // 32-bit float (most common from AVCaptureAudioDataOutput)
            let samples = raw.bindMemory(to: Float.self, capacity: frameCount * channelCount)
            for i in 0..<(frameCount * channelCount) {
                let s = samples[i]
                sum += s * s
            }
        } else if !isFloat && bytesPerSample == 2 {
            // 16-bit signed integer
            let samples = raw.bindMemory(to: Int16.self, capacity: frameCount * channelCount)
            for i in 0..<(frameCount * channelCount) {
                let s = Float(samples[i]) / Float(Int16.max)
                sum += s * s
            }
        } else {
            return nil
        }

        let rms = sqrt(sum / Float(frameCount * channelCount))

        if rms > 0 {
            return 20 * log10(rms)
        }
        return -160
    }
}
