import Foundation
import Testing
@testable import VibratoCore

/// ScorePlayback 的补充边界测试：速度/循环钳制、空乐谱、事件查找与渲染上限。
struct ScorePlaybackEdgeTests {
    private func makeScore() -> ImportedScore {
        ImportedScore(
            title: "边界测试",
            bpm: 60,
            notes: [
                ScoreNote(midiNote: 62, startBeat: 0, durationBeats: 1),
                ScoreNote(midiNote: 64, startBeat: 1, durationBeats: 1),
                ScoreNote(midiNote: 66, startBeat: 2, durationBeats: 2)
            ],
            measureStartBeats: [0, 2],
            divisions: 1
        )
    }

    @Test("速度倍率被限制在 0.4–1.2 之间")
    func clampsTempoScaleToSupportedRange() {
        let score = makeScore()

        let slow = ScorePlayback.timeline(score: score, tempoScale: 0.01)
        #expect(slow.tempoScale == ScorePlayback.minimumTempoScale)
        #expect(abs(slow.totalSeconds - 10) < 0.000_1)

        let fast = ScorePlayback.timeline(score: score, tempoScale: 5)
        #expect(fast.tempoScale == ScorePlayback.maximumTempoScale)
        #expect(abs(fast.totalSeconds - 4 * 60 / 72) < 0.000_1)
    }

    @Test("越界的小节循环范围按整首乐谱处理")
    func clampsLoopRangeToAvailableMeasures() {
        let score = makeScore()
        let whole = ScorePlayback.timeline(score: score)
        let clamped = ScorePlayback.timeline(score: score, loopMeasures: 0...99)

        #expect(clamped.events.map(\.id) == whole.events.map(\.id))
        #expect(clamped.events.map(\.startSeconds) == whole.events.map(\.startSeconds))
        #expect(clamped.totalSeconds == whole.totalSeconds)
    }

    @Test("空乐谱生成空时间轴，但预备拍仍然存在")
    func handlesEmptyScore() {
        let empty = ImportedScore(
            title: "空乐谱",
            bpm: 60,
            notes: [],
            measureStartBeats: [],
            divisions: 1
        )

        let plain = ScorePlayback.timeline(score: empty)
        #expect(plain.events.isEmpty)
        #expect(plain.clicks.isEmpty)
        #expect(plain.leadInSeconds == 0)
        #expect(plain.totalSeconds == 0)

        let counted = ScorePlayback.timeline(score: empty, countInMeasures: 1)
        #expect(counted.events.isEmpty)
        #expect(counted.leadInSeconds == 4)
        #expect(counted.totalSeconds == 4)
        #expect(counted.clicks.map(\.seconds) == [0, 1, 2, 3])
    }

    @Test("负数预备拍等同于关闭预备拍")
    func treatsNegativeCountInAsDisabled() {
        let score = makeScore()
        let zero = ScorePlayback.timeline(score: score, countInMeasures: 0)
        let negative = ScorePlayback.timeline(score: score, countInMeasures: -3)

        #expect(negative.leadInSeconds == 0)
        #expect(negative.totalSeconds == zero.totalSeconds)
        #expect(negative.clicks == zero.clicks)
    }

    @Test("eventIndex 在首个音符前返回 nil，之后返回最近开始的音符")
    func resolvesCurrentEventAcrossGaps() {
        let score = ImportedScore(
            title: "空拍",
            bpm: 60,
            notes: [
                ScoreNote(midiNote: 62, startBeat: 1, durationBeats: 1),
                ScoreNote(midiNote: 64, startBeat: 3, durationBeats: 1)
            ],
            measureStartBeats: [0],
            divisions: 1
        )
        let plan = ScorePlayback.timeline(score: score)

        #expect(plan.events.map(\.startSeconds) == [1, 3])
        #expect(plan.eventIndex(at: 0.5) == nil)
        #expect(plan.eventIndex(at: 1.0) == 0)
        #expect(plan.eventIndex(at: 2.9) == 0)
        #expect(plan.eventIndex(at: 3.0) == 1)
        #expect(plan.eventIndex(at: 100) == 1)
    }

    @Test("非法采样率返回空数组，采样长度包含收音余量")
    func rendersExpectedBufferLength() {
        let plan = ScorePlayback.timeline(score: makeScore())
        #expect(ScorePlayback.renderSamples(timeline: plan, sampleRate: 0).isEmpty)
        #expect(ScorePlayback.renderSamples(timeline: plan, sampleRate: -8_000).isEmpty)

        let samples = ScorePlayback.renderSamples(timeline: plan, sampleRate: 8_000)
        let expected = Int(((plan.totalSeconds + 0.06) * 8_000).rounded(.up))
        #expect(samples.count == expected)
        #expect(samples.count >= Int(plan.totalSeconds * 8_000))
    }

    @Test("多音叠加时削波保护生效")
    func clampsOverlappingTones() {
        let overlapping = ScorePlaybackTimeline(
            events: (0..<8).map { index in
                ScorePlaybackEvent(id: index, midiNote: 69, startSeconds: 0, durationSeconds: 0.5)
            },
            totalSeconds: 0.5,
            tempoScale: 1
        )
        let samples = ScorePlayback.renderSamples(timeline: overlapping, sampleRate: 8_000)

        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { abs($0) <= 0.98 })
        #expect(samples.max() == 0.98)
    }
}
