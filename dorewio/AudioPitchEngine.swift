import AVFoundation

@MainActor
final class AudioPitchEngine {
    private let analysisQueue = DispatchQueue(label: "com.archintera.VibratoCoach.pitch-analysis", qos: .userInitiated)
    private let analysisGate = DispatchSemaphore(value: 1)
    private var engine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var tapInstalled = false

    func start(onFrequency: @escaping @Sendable (Double) -> Void) throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        let newEngine = AVAudioEngine()
        let input = newEngine.inputNode
        let hardwareFormat = input.inputFormat(forBus: 0)
        guard AudioInputAvailability.isUsable(
            sampleRate: hardwareFormat.sampleRate,
            channelCount: hardwareFormat.channelCount
        ) else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw AudioPitchEngineError.inputUnavailable
        }

        let analysisQueue = analysisQueue
        let analysisGate = analysisGate
        input.installTap(onBus: 0, bufferSize: 2_048, format: nil) { buffer, _ in
            guard let channel = buffer.floatChannelData?.pointee else { return }
            guard analysisGate.wait(timeout: .now()) == .success else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            let sampleRate = buffer.format.sampleRate
            analysisQueue.async {
                defer { analysisGate.signal() }
                guard let frequency = PitchDetector.estimateFrequency(
                    samples: samples,
                    sampleRate: sampleRate
                ) else { return }
                onFrequency(frequency)
            }
        }
        tapInstalled = true
        engine = newEngine
        inputNode = input

        newEngine.prepare()
        do {
            try newEngine.start()
        } catch {
            stop()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func stop() {
        if engine?.isRunning == true { engine?.stop() }
        removeTapIfNeeded()
        engine?.reset()
        inputNode = nil
        engine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func removeTapIfNeeded() {
        guard tapInstalled, let inputNode else { return }
        inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }
}

enum AudioPitchEngineError: Error {
    case inputUnavailable
}
