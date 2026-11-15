import AVFoundation
import Combine

/// Short violin-like note playback for fingerboard answers and reference tones.
@MainActor
final class ViolinNotePlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat?
    private var buffers: [Int: AVAudioPCMBuffer] = [:]
    private var configured = false
    private var demoBuffer: AVAudioPCMBuffer?

    init() {
        engine.attach(player)
    }

    func play(midiNote: Int) {
        ensureEngine()
        guard let buffer = buffer(for: midiNote) else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    func playFrequency(_ frequency: Double) {
        ensureEngine()
        guard let buffer = makeBuffer(frequency: frequency, duration: 0.9, vibrato: nil) else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    /// A short synthesised vibrato demo (5.5 Hz, ±30 cents).
    func playVibratoDemo(frequency: Double) {
        ensureEngine()
        guard let buffer = makeBuffer(
            frequency: frequency,
            duration: 1.8,
            vibrato: (rate: 5.5, depthCents: 30)
        ) else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    func stop() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func ensureEngine() {
        guard !engine.isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !configured {
                format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                configured = true
            }
            engine.prepare()
            try engine.start()
            player.play()
        } catch {
            // Silent failure: the UI still works, haptics and visuals remain.
        }
    }

    private func buffer(for midiNote: Int) -> AVAudioPCMBuffer? {
        if let buffer = buffers[midiNote] { return buffer }
        let frequency = 440 * pow(2, Double(midiNote - 69) / 12)
        guard let buffer = makeBuffer(frequency: frequency, duration: 0.9, vibrato: nil) else { return nil }
        buffers[midiNote] = buffer
        return buffer
    }

    private func makeBuffer(
        frequency: Double,
        duration: Double,
        vibrato: (rate: Double, depthCents: Double)?
    ) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = Int(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let harmonics: [(multiple: Double, gain: Double)] = [
            (1, 1.0), (2, 0.42), (3, 0.26), (4, 0.14), (5, 0.07)
        ]
        var phase = 0.0
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let attack = min(1, time / 0.02)
            let decay = exp(-time * (duration > 1 ? 0.9 : 3.2))
            let envelope = attack * decay
            var instantaneous = frequency
            if let vibrato {
                let cents = vibrato.depthCents * sin(2 * .pi * vibrato.rate * time)
                instantaneous *= pow(2, cents / 1_200)
            }
            var sample = 0.0
            for harmonic in harmonics {
                sample += sin(phase * harmonic.multiple) * harmonic.gain
            }
            sample *= envelope * 0.18
            channel[frame] = Float(sample)
            phase += 2 * .pi * instantaneous / sampleRate
            if phase > 2 * .pi { phase -= 2 * .pi }
        }
        return buffer
    }
}

/// Continuous violin tone whose pitch can be bent by a touch gesture.
/// Uses a seamless looping buffer plus AVAudioUnitTimePitch instead of a
/// realtime source-node callback, which keeps the audio graph stable while
/// the user drags (the previous source-node version could trap on device).
final class VibratoTouchEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var configured = false
    private var isRunning = false
    private var loopBuffer: AVAudioPCMBuffer?

    init() {
        engine.attach(player)
        engine.attach(timePitch)
    }

    func start(baseFrequency: Double) {
        stop()
        guard let format else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !configured {
                engine.connect(player, to: timePitch, format: format)
                engine.connect(timePitch, to: engine.mainMixerNode, format: format)
                configured = true
            }
            loopBuffer = makeLoop(frequency: baseFrequency)
            timePitch.pitch = 0
            engine.prepare()
            try engine.start()
            player.play()
            if let loopBuffer {
                player.scheduleBuffer(loopBuffer, at: nil, options: .loops)
            }
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func setCents(_ cents: Double) {
        timePitch.pitch = Float(max(-100, min(100, cents)))
    }

    func stop() {
        guard isRunning else { return }
        player.stop()
        engine.stop()
        engine.reset()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Generates an integer number of periods so the loop is seamless.
    private func makeLoop(frequency: Double) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let sampleRate = 44_100.0
        let cycles = max(1, Int((frequency * 0.6).rounded()))
        let duration = Double(cycles) / frequency
        let frameCount = Int(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let harmonics: [(Double, Double)] = [(1, 1.0), (2, 0.42), (3, 0.24), (4, 0.12)]
        var phase = 0.0
        for frame in 0..<frameCount {
            var sample = 0.0
            for harmonic in harmonics {
                sample += sin(phase * harmonic.0) * harmonic.1
            }
            channel[frame] = Float(sample * 0.16)
            phase += 2 * .pi * frequency / sampleRate
        }
        return buffer
    }
}
