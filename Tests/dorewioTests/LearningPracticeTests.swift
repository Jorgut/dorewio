import Foundation
import Testing
@testable import VibratoCore

struct LearningPracticeTests {
    @Test("四根空弦按音高排列并使用标准频率")
    func openStringsUseStandardPitches() {
        #expect(ViolinString.allCases.map(\.rawValue) == ["G", "D", "A", "E"])
        #expect(ViolinString.allCases.map(\.midiNote) == [55, 62, 69, 76])
        #expect(abs(ViolinString.a.frequency - 440) < 0.001)
    }

    @Test("第一把位包含每根弦的空弦与一二三指")
    func firstPositionCoversBeginnerFingering() {
        #expect(FirstPositionFingerboard.positions.count == 16)
        #expect(FirstPositionFingerboard.position(on: .d, finger: 2)?.noteName == "F4")
        #expect(FirstPositionFingerboard.position(on: .e, finger: 3)?.noteName == "A5")
    }

    @Test("基础识谱音符都能映射到第一把位")
    func staffNotesMapToFingerboard() {
        #expect(!BeginnerNoteBank.notes.isEmpty)
        #expect(BeginnerNoteBank.notes.allSatisfy { note in
            FirstPositionFingerboard.positions.contains { $0.midiNote == note.midiNote }
        })
    }

    @Test("十分钟无琴课程包含识谱指板节奏与听辨")
    func dailyCourseHasCompleteLearningLoop() {
        #expect(NoInstrumentCourse.tasks.map(\.skill) == [
            .sightReading, .fingerboard, .rhythm, .earTraining
        ])
        #expect(NoInstrumentCourse.tasks.reduce(0) { $0 + $1.minutes } == 10)
    }

    @Test("技能进度按完成次数和平均正确率汇总")
    func summarizesSkillProgress() throws {
        let records = [
            PracticeRecord(kind: .sightReading, startedAt: .now, duration: 60, score: 80),
            PracticeRecord(kind: .sightReading, startedAt: .now, duration: 60, score: 100),
            PracticeRecord(kind: .earTraining, startedAt: .now, duration: 60, score: 50),
            PracticeRecord(kind: .rhythm, startedAt: .now, duration: 60, score: nil)
        ]

        let summary = LearningProgress.summary(for: .sightReading, records: records)
        #expect(summary.completedSessions == 2)
        #expect(summary.averageScore == 90)
        #expect(LearningProgress.summary(for: .fingerboard, records: records).averageScore == nil)
    }
}

struct PracticeToneGeneratorTests {
    @Test("示范音保持四根空弦的标准音高")
    func generatedTonesKeepOpenStringPitch() throws {
        let sampleRate = 44_100.0

        for violinString in ViolinString.allCases {
            let samples = PracticeToneGenerator.samples(
                frequency: violinString.frequency,
                duration: 0.5,
                sampleRate: sampleRate
            )
            let steadySamples = Array(samples[4_410..<8_506])
            let detected = try #require(
                PitchDetector.estimateFrequency(
                    samples: steadySamples,
                    sampleRate: sampleRate,
                    minimumFrequency: 150,
                    maximumFrequency: 800
                )
            )
            let cents = 1_200 * log2(detected / violinString.frequency)

            #expect(abs(cents) < 5)
        }
    }

    @Test("示范音包含小提琴式泛音且首尾平滑")
    func generatedToneHasHarmonicsAndEnvelope() {
        let sampleRate = 44_100.0
        let frequency = ViolinString.a.frequency
        let samples = PracticeToneGenerator.samples(
            frequency: frequency,
            duration: 0.5,
            sampleRate: sampleRate
        )

        #expect(samples.count == 22_050)
        #expect(abs(samples.first ?? 1) < 0.001)
        #expect(abs(samples.last ?? 1) < 0.001)

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

        #expect(secondHarmonic > fundamental * 0.15)
    }

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
}
