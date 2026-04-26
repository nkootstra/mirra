import AVFoundation
import Combine

/// Monitors the default input audio device and publishes the current mic level (0...1).
/// Requires microphone permission and the audio device entitlement.
@MainActor
final class MicLevelMonitor: ObservableObject {
    @Published var level: Float = 0
    @Published var isActive: Bool = false

    private var worker: AudioWorker?
    private var pollTimer: Timer?

    func start() {
        guard worker == nil else { return }

        let w = AudioWorker()
        w.start()
        worker = w

        // Poll the level from the worker at ~30Hz
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self, weak w] _ in
            Task { @MainActor [weak self] in
                self?.level = w?.currentLevel ?? 0
                self?.isActive = w?.isRunning ?? false
            }
        }
        isActive = true
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        worker?.stop()
        worker = nil
        isActive = false
        level = 0
    }
}

/// Non-MainActor worker that owns the AVAudioEngine and tap.
/// All audio work happens off the main actor.
private final class AudioWorker: @unchecked Sendable {
    private let lock = NSLock()
    private var _level: Float = 0
    private var _isRunning = false
    private var engine: AVAudioEngine?

    var currentLevel: Float {
        lock.withLock { _level }
    }

    var isRunning: Bool {
        lock.withLock { _isRunning }
    }

    func start() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            guard let data = channelData, frameLength > 0 else { return }

            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = data[i]
                sum += sample * sample
            }
            let rms = sqrtf(sum / Float(frameLength))
            let normalized = min(rms * 10, 1.0)
            self.lock.withLock { self._level = normalized }
        }

        do {
            try engine.start()
            self.engine = engine
            lock.withLock { _isRunning = true }
        } catch {
            lock.withLock { _isRunning = false }
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        lock.withLock {
            _isRunning = false
            _level = 0
        }
    }
}
