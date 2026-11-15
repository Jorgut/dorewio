import AVFoundation

/// Lightweight synthesized metronome click player used by the metronome and
/// the bowing practice screen. Keeps one AVAudioEngine alive while the screen
/// is visible and schedules a short buffer per beat.
@MainActor
final class MetronomeClickPlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var clickBuffer: AVAudioPCMBuffer?
    private var accentBuffer: AVAudioPCMBuffer?
    private var configured = false

    @Published var isEnabled = true

    init() {
        engine.attach(player)
        clickBuffer = Self.makeClick(frequency: 1320)
        accentBuffer = Self.makeClick(frequency: 1760)
    }

    func start() {
        guard !engine.isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !configured, let format = clickBuffer?.format {
                engine.connect(player, to: engine.mainMixerNode, format: format)
                configured = true
            }
            engine.prepare()
            try engine.start()
            player.play()
        } catch {
            // A failed click should never interrupt practice; the UI keeps
            // working with haptics only.
        }
    }

    func play(accent: Bool) {
        guard isEnabled else { return }
        if !engine.isRunning { start() }
        guard engine.isRunning, let buffer = accent ? accentBuffer : clickBuffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    func stop() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func makeClick(frequency: Double) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = Int(sampleRate * 0.045)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let envelope = exp(-time * 85)
            let sample = sin(2 * .pi * frequency * time) * envelope * 0.55
            channel[frame] = Float(sample)
        }
        return buffer
    }
}
