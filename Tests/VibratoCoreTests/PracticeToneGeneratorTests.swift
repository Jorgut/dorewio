import Foundation
import Testing
@testable import VibratoCore

/// 示范音（带小提琴式泛音）的音高、包络与边界行为测试。
struct PracticeToneGeneratorTests {
    private let sampleRate = 44_100.0
    private let frequency = 440.0

    @Test("示范音采样数量、幅度与首尾包络")
    func generatedToneHasExpectedLengthAndEnvelope() {
        let samples = PracticeToneGenerator.samples(
            frequency: frequency,
            duration: 0.5,
            sampleRate: sampleRate
        )

        #expect(samples.count == 22_050)
        #expect(samples.allSatisfy { $0.isFinite && abs($0) <= 0.5 })
        #expect(samples.contains { abs($0) > 0.05 })
        // 起音与收音都有包络，首尾接近静音，避免爆音。
        #expect(abs(samples.first ?? 1) < 0.001)
        #expect(abs(samples.last ?? 1) < 0.001)
    }

    @Test("示范音保持基频并带可测的二次与三次泛音")
    func generatedToneKeepsFundamentalAndHarmonics() {
        let samples = PracticeToneGenerator.samples(
            frequency: frequency,
            duration: 0.5,
            sampleRate: sampleRate
        )
        let steadySamples = Array(samples[4_410..<8_506])

        let fundamental = sinusoidMagnitude(
            samples: steadySamples,
            frequency: frequency,
            sampleRate: sampleRate
        )
        let secondHarmonic = sinusoidMagnitude(
            samples: steadySamples,
            frequency: frequency * 2,
            sampleRate: sampleRate
        )
        let thirdHarmonic = sinusoidMagnitude(
            samples: steadySamples,
            frequency: frequency * 3,
            sampleRate: sampleRate
        )

        #expect(fundamental > 0.05)
        #expect(secondHarmonic > fundamental * 0.3)
        #expect(thirdHarmonic > fundamental * 0.15)
    }

    @Test("四根空弦的过零率随音高升高")
    func generatedTonesRiseWithOpenStringPitch() {
        let crossings = FingeringString.allCases.map { string -> Int in
            let samples = PracticeToneGenerator.samples(
                frequency: string.frequency,
                duration: 0.5,
                sampleRate: sampleRate
            )
            return signChanges(in: Array(samples[4_410..<8_506]))
        }

        #expect(crossings == crossings.sorted())
        #expect(crossings.first ?? 0 > 0)
        #expect(Set(crossings).count == crossings.count)
    }

    @Test("非法频率、时长与采样率返回空数组")
    func rejectsInvalidParameters() {
        #expect(PracticeToneGenerator.samples(frequency: 0, duration: 0.5, sampleRate: sampleRate).isEmpty)
        #expect(PracticeToneGenerator.samples(frequency: -440, duration: 0.5, sampleRate: sampleRate).isEmpty)
        #expect(PracticeToneGenerator.samples(frequency: 440, duration: 0, sampleRate: sampleRate).isEmpty)
        #expect(PracticeToneGenerator.samples(frequency: 440, duration: -1, sampleRate: sampleRate).isEmpty)
        #expect(PracticeToneGenerator.samples(frequency: 440, duration: 0.5, sampleRate: 0).isEmpty)
    }

    @Test("时长不足一个采样帧时返回空数组")
    func rejectsSubFrameDuration() {
        let samples = PracticeToneGenerator.samples(
            frequency: 440,
            duration: 0.000_01,
            sampleRate: 1_000
        )
        #expect(samples.isEmpty)
    }

    // MARK: - 辅助

    /// 单个正弦分量的离散傅里叶幅值（与旧 PracticeToneGeneratorTests 的断言方式一致）。
    private func sinusoidMagnitude(
        samples: [Float],
        frequency: Double,
        sampleRate: Double
    ) -> Double {
        let components = samples.enumerated().reduce(into: (sine: 0.0, cosine: 0.0)) { result, pair in
            let phase = 2 * Double.pi * frequency * Double(pair.offset) / sampleRate
            result.sine += Double(pair.element) * sin(phase)
            result.cosine += Double(pair.element) * cos(phase)
        }
        return hypot(components.sine, components.cosine) / Double(samples.count)
    }

    private func signChanges(in samples: [Float]) -> Int {
        guard samples.count > 1 else { return 0 }
        var count = 0
        for index in 1..<samples.count {
            let previous = samples[index - 1]
            let current = samples[index]
            if abs(previous) > 0.000_01,
               abs(current) > 0.000_01,
               (previous < 0) != (current < 0) {
                count += 1
            }
        }
        return count
    }
}
