import AVFoundation

@MainActor
final class TonePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    init() {
        engine.attach(player)
    }

    func play(frequency: Double, duration: TimeInterval = 1) {
        stop()

        let outputSampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = outputSampleRate > 0 ? outputSampleRate : 44_100
        let generatedSamples = PracticeToneGenerator.samples(
            frequency: frequency,
            duration: duration,
            sampleRate: sampleRate
        )
        let frameCount = AVAudioFrameCount(generatedSamples.count)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = frameCount
        for (frame, sample) in generatedSamples.enumerated() {
            samples[frame] = sample
        }

        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            stop()
        }
    }

    func stop() {
        player.stop()
        if engine.isRunning { engine.stop() }
        engine.reset()
    }
}
