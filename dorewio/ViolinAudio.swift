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
final class VibratoTouchEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let lock = NSLock()
    private var baseFrequency = 440.0
    private var cents = 0.0
    private var amplitude = 0.0
    private var phase = 0.0
    private var isRunning = false

    func start(baseFrequency: Double) {
        self.baseFrequency = baseFrequency
        cents = 0
        amplitude = 0.28
        phase = 0
        guard !isRunning else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
            let source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self else { return noErr }
                self.lock.lock()
                let base = self.baseFrequency
                let cents = self.cents
                let level = self.amplitude
                var phase = self.phase
                self.lock.unlock()

                let frequency = base * pow(2, cents / 1_200)
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                guard let channel = abl.first?.mData?.assumingMemoryBound(to: Float.self) else {
                    return noErr
                }
                let harmonics: [(Double, Double)] = [(1, 1.0), (2, 0.42), (3, 0.24), (4, 0.12)]
                for frame in 0..<Int(frameCount) {
                    var sample = 0.0
                    for harmonic in harmonics {
                        sample += sin(phase * harmonic.0) * harmonic.1
                    }
                    sample *= level * 0.16
                    channel[frame] = Float(sample)
                    phase += 2 * .pi * frequency / 44_100
                    if phase > 2 * .pi { phase -= 2 * .pi }
                }
                self.lock.lock()
                self.phase = phase
                self.lock.unlock()
                return noErr
            }
            sourceNode = source
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func setCents(_ cents: Double) {
        lock.lock()
        self.cents = max(-100, min(100, cents))
        lock.unlock()
    }

    func stop() {
        guard isRunning else { return }
        lock.lock()
        amplitude = 0
        lock.unlock()
        engine.stop()
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
