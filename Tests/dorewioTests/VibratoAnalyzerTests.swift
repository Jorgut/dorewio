import Foundation
import Testing
@testable import VibratoCore

struct VibratoAnalyzerTests {
    private let analyzer = VibratoAnalyzer()

    @Test("稳定揉弦返回速度、幅度和高稳定度")
    func analyzesSteadyVibrato() throws {
        let samples = makeSamples(
            duration: 2,
            sampleRate: 50,
            centerCents: 0,
            amplitudeCents: 30,
            rateHz: 5
        )

        let result = try #require(analyzer.analyze(samples: samples))

        #expect(abs(result.rateHz - 5) < 0.3)
        #expect(abs(result.extentCents - 60) < 4)
        #expect(result.regularity > 0.9)
        #expect(abs(result.centerOffsetCents) < 1)
    }

    @Test("幅度过窄时给出明确反馈")
    func reportsNarrowExtent() throws {
        let samples = makeSamples(
            duration: 2,
            sampleRate: 50,
            centerCents: 0,
            amplitudeCents: 7,
            rateHz: 5
        )

        let result = try #require(analyzer.analyze(samples: samples))

        #expect(result.feedback == .tooNarrow)
    }

    @Test("整体偏高时保留揉弦中心偏移")
    func reportsSharpCenter() throws {
        let samples = makeSamples(
            duration: 2,
            sampleRate: 50,
            centerCents: 18,
            amplitudeCents: 25,
            rateHz: 5
        )

        let result = try #require(analyzer.analyze(samples: samples))

        #expect(abs(result.centerOffsetCents - 18) < 1)
        #expect(result.feedback == .centerSharp)
    }

    @Test("样本不足时不产生分析结果")
    func rejectsInsufficientSamples() {
        let samples = [PitchSample(time: 0, centsFromTarget: 0)]

        #expect(analyzer.analyze(samples: samples) == nil)
    }

    private func makeSamples(
        duration: Double,
        sampleRate: Double,
        centerCents: Double,
        amplitudeCents: Double,
        rateHz: Double
    ) -> [PitchSample] {
        let count = Int(duration * sampleRate)
        return (0..<count).map { index in
            let time = Double(index) / sampleRate
            let cents = centerCents
                + amplitudeCents * sin(2 * .pi * rateHz * time)
            return PitchSample(time: time, centsFromTarget: cents)
        }
    }
}

struct PitchDetectorTests {
    @Test("识别 440 Hz 正弦波")
    func detectsConcertA() throws {
        let sampleRate = 44_100.0
        let samples = (0..<2_048).map { index in
            Float(sin(2 * .pi * 440 * Double(index) / sampleRate))
        }

        let frequency = try #require(
            PitchDetector.estimateFrequency(samples: samples, sampleRate: sampleRate)
        )

        #expect(abs(frequency - 440) < 2)
    }

    @Test("静音不返回虚假音高")
    func rejectsSilence() {
        let samples = Array(repeating: Float.zero, count: 2_048)

        #expect(
            PitchDetector.estimateFrequency(samples: samples, sampleRate: 44_100) == nil
        )
    }

    @Test("输入帧过短时不尝试识别")
    func rejectsShortFrame() {
        let samples = Array(repeating: Float(0.5), count: 128)

        #expect(
            PitchDetector.estimateFrequency(samples: samples, sampleRate: 44_100) == nil
        )
    }
}
