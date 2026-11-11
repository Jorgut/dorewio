import AVFoundation
import Foundation

/// Synthesized reference pitch, not an acoustic violin recording.
final class TonePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(midi: Int) {
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let duration = 0.65
        let count = Int(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let samples = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = AVAudioFrameCount(count)
        let hz = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
        for index in 0..<count {
            let t = Double(index) / sampleRate
            let fadeIn = min(1.0, t / 0.020)
            let fadeOut = min(1.0, (duration - t) / 0.080)
            samples[index] = Float(0.16 * max(0, min(fadeIn, fadeOut)) * sin(2.0 * .pi * hz * t))
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }
}
