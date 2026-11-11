import Foundation

public enum PracticeToneGenerator {
    public static func samples(
        frequency: Double,
        duration: TimeInterval,
        sampleRate: Double
    ) -> [Float] {
        guard frequency > 0, duration > 0, sampleRate > 0 else { return [] }

        let frameCount = Int(sampleRate * duration)
        guard frameCount > 0 else { return [] }

        let harmonics: [(multiple: Double, amplitude: Double, phase: Double)] = [
            (1, 1.00, 0.00),
            (2, 0.42, 0.18),
            (3, 0.26, 0.47),
            (4, 0.16, 0.73),
            (5, 0.10, 1.05),
            (6, 0.06, 1.31)
        ]
        let normalization = harmonics.reduce(0) { $0 + $1.amplitude }
        let attackDuration = min(0.04, duration * 0.2)
        let releaseDuration = min(0.08, duration * 0.25)

        return (0..<frameCount).map { frame in
            let time = Double(frame) / sampleRate
            let attack = attackDuration > 0 ? min(1, time / attackDuration) : 1
            let remaining = max(0, duration - time)
            let release = releaseDuration > 0 ? min(1, remaining / releaseDuration) : 1
            let bowEnvelope = attack * release * (1 - 0.08 * time / duration)
            let phase = 2 * Double.pi * frequency * time
            let waveform = harmonics.reduce(0.0) { partial, harmonic in
                partial + harmonic.amplitude * sin(phase * harmonic.multiple + harmonic.phase)
            }
            return Float(waveform / normalization * bowEnvelope * 0.42)
        }
    }
}
