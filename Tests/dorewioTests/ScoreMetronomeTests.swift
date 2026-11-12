import Foundation
import Testing
@testable import VibratoCore

/// 「按谱演奏」节拍器与一小节预备拍（count-in）的行为测试。
///
/// 固定用 60 BPM，一拍 = 1 秒，方便直接断言秒数。
struct ScoreMetronomeTests {
    /// 两个四拍小节：正曲共 6 拍（第二个小节只到第 6 拍）。
    private func makeScore(bpm: Double = 60) -> ImportedScore {
        ImportedScore(
            title: "节拍测试",
            bpm: bpm,
            notes: [
                ScoreNote(midiNote: 62, startBeat: 0, durationBeats: 1),
                ScoreNote(midiNote: 64, startBeat: 1, durationBeats: 1),
                ScoreNote(midiNote: 66, startBeat: 2, durationBeats: 1),
                ScoreNote(midiNote: 67, startBeat: 3, durationBeats: 1),
                ScoreNote(midiNote: 69, startBeat: 4, durationBeats: 2)
            ],
            measureStartBeats: [0, 4],
            divisions: 1
        )
    }

    /// 只在第一拍有个短音、其余为休止的乐谱，便于隔离 click 能量。
    private func makeSparseScore() -> ImportedScore {
        ImportedScore(
            title: "休止",
            bpm: 60,
            notes: [ScoreNote(midiNote: 62, startBeat: 0, durationBeats: 1)],
            measureStartBeats: [0, 4],
            divisions: 1
        )
    }

    private func peak(
        of samples: [Float],
        from startSeconds: Double,
        to endSeconds: Double,
        sampleRate: Double = 8_000
    ) -> Float {
        let start = max(0, Int((startSeconds * sampleRate).rounded(.down)))
        let end = min(samples.count, Int((endSeconds * sampleRate).rounded(.up)))
        guard start < end else { return 0 }
        return samples[start..<end].reduce(0) { max($0, abs($1)) }
    }

    private func signChanges(
        in samples: [Float],
        from startSeconds: Double,
        to endSeconds: Double,
        sampleRate: Double
    ) -> Int {
        let start = max(0, Int((startSeconds * sampleRate).rounded(.down)))
        let end = min(samples.count, Int((endSeconds * sampleRate).rounded(.up)))
        guard start + 1 < end else { return 0 }
        var count = 0
        for index in (start + 1)..<end {
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

    @Test("预备拍让总时长增加但音符起点不变")
    func countInExtendsTotalButKeepsEvents() {
        let plain = ScorePlayback.timeline(score: makeScore())
        let counted = ScorePlayback.timeline(score: makeScore(), countInMeasures: 1)

        #expect(plain.leadInSeconds == 0)
        #expect(plain.totalSeconds == 6)
        #expect(counted.leadInSeconds == 4)
        #expect(counted.totalSeconds == 10)
        #expect(counted.totalSeconds == plain.totalSeconds + counted.leadInSeconds)
        #expect(counted.events.map(\.startSeconds) == plain.events.map(\.startSeconds))
        #expect(counted.events.map(\.durationSeconds) == plain.events.map(\.durationSeconds))
        #expect(counted.events.map(\.id) == plain.events.map(\.id))
    }

    @Test("关闭预备拍时只有正曲拍点")
    func withoutCountInOnlyScoreClicks() {
        let plan = ScorePlayback.timeline(score: makeScore(), countInMeasures: 0)

        #expect(plan.leadInSeconds == 0)
        #expect(plan.clicks.map(\.seconds) == [0, 1, 2, 3, 4, 5])
        #expect(plan.clicks.filter(\.isDownbeat).map(\.seconds) == [0, 4])
    }

    @Test("一小节预备拍按拍生成，重拍在小节起点")
    func countInClicksCoverLeadInAndScore() {
        let plan = ScorePlayback.timeline(score: makeScore(), countInMeasures: 1)

        #expect(plan.leadInSeconds == 4)
        #expect(plan.totalSeconds == 10)
        #expect(plan.clicks.map(\.seconds) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        #expect(plan.clicks.filter(\.isDownbeat).map(\.seconds) == [0, 4, 8])
        // 预备拍第一拍就是重拍。
        #expect(plan.clicks.first?.isDownbeat == true)
    }

    @Test("预备拍超过上限时只保留一小节")
    func countInIsClampedToOneMeasure() {
        #expect(ScorePlayback.maximumCountInMeasures == 1)

        let clamped = ScorePlayback.timeline(score: makeScore(), countInMeasures: 5)
        #expect(clamped.leadInSeconds == 4)
        #expect(clamped.totalSeconds == 10)
        #expect(clamped == ScorePlayback.timeline(score: makeScore(), countInMeasures: 1))
    }

    @Test("预备拍取第一小节长度，单小节乐谱回退四拍")
    func countInUsesFirstMeasureLength() {
        let waltz = ImportedScore(
            title: "三拍",
            bpm: 60,
            notes: [ScoreNote(midiNote: 62, startBeat: 0, durationBeats: 3)],
            measureStartBeats: [0, 3],
            divisions: 1
        )
        let waltzPlan = ScorePlayback.timeline(score: waltz, countInMeasures: 1)
        #expect(waltzPlan.leadInSeconds == 3)
        #expect(waltzPlan.clicks.filter { $0.seconds < waltzPlan.leadInSeconds }.count == 3)
        #expect(waltzPlan.clicks.contains { $0.seconds < waltzPlan.leadInSeconds && $0.isDownbeat })

        let singleMeasure = ImportedScore(
            title: "单小节",
            bpm: 60,
            notes: [ScoreNote(midiNote: 62, startBeat: 0, durationBeats: 2)],
            measureStartBeats: [0],
            divisions: 1
        )
        let singlePlan = ScorePlayback.timeline(score: singleMeasure, countInMeasures: 1)
        #expect(singlePlan.leadInSeconds == 4)
        #expect(singlePlan.totalSeconds == 6)
    }

    @Test("预备拍期间返回 nil，之后返回正确音符")
    func eventIndexSkipsCountIn() {
        let plan = ScorePlayback.timeline(score: makeScore(), countInMeasures: 1)

        #expect(plan.eventIndex(at: 0) == nil)
        #expect(plan.eventIndex(at: 3.99) == nil)
        #expect(plan.eventIndex(at: 4.0) == 0)
        #expect(plan.eventIndex(at: 5.5) == 1)
        #expect(plan.eventIndex(at: 8.0) == 4)
        #expect(plan.eventIndex(at: 9.5) == 4)
    }

    @Test("关闭节拍器只渲染预备拍，开启后渲染全部拍点")
    func rendersClicksRespectingMetronomeSwitch() {
        let plan = ScorePlaybackTimeline(
            events: [],
            totalSeconds: 2.5,
            tempoScale: 1,
            leadInSeconds: 1.5,
            clicks: [
                ScoreClick(seconds: 0, isDownbeat: true),
                ScoreClick(seconds: 1.5, isDownbeat: false)
            ]
        )

        let countInOnly = ScorePlayback.renderSamples(timeline: plan, sampleRate: 8_000)
        let full = ScorePlayback.renderSamples(timeline: plan, sampleRate: 8_000, metronomeEnabled: true)

        #expect(countInOnly.count >= Int(plan.totalSeconds * 8_000))
        #expect(full.count == countInOnly.count)
        // 预备拍 click 始终存在，且峰值可测、不削波。
        #expect(peak(of: countInOnly, from: 0, to: 0.05) > 0.1)
        #expect(peak(of: full, from: 0, to: 0.05) > 0.1)
        #expect(countInOnly.allSatisfy { abs($0) <= 0.98 })
        // 关闭节拍器时正曲拍点必须静音，开启后才有声音。
        #expect(peak(of: countInOnly, from: 1.45, to: 1.6) < 0.001)
        #expect(peak(of: full, from: 1.45, to: 1.6) > 0.1)
    }

    @Test("打开节拍器时正曲拍点也有声音")
    func metronomeAddsScoreClicks() {
        let plan = ScorePlayback.timeline(score: makeSparseScore())
        #expect(plan.clicks.map(\.seconds) == [0, 1, 2, 3])

        let withoutClick = ScorePlayback.renderSamples(timeline: plan, sampleRate: 8_000)
        let withClick = ScorePlayback.renderSamples(
            timeline: plan,
            sampleRate: 8_000,
            metronomeEnabled: true
        )

        // 第 2 拍处乐谱本身没有声音，只有 click 会带来能量。
        #expect(peak(of: withoutClick, from: 1.95, to: 2.05) < 0.001)
        #expect(peak(of: withClick, from: 1.95, to: 2.05) > 0.1)
        #expect(withClick.allSatisfy { abs($0) <= 0.98 })
    }

    @Test("重拍 click 音高更高")
    func downbeatClickHasHigherPitch() {
        let sampleRate = 44_100.0
        let downbeatPlan = ScorePlaybackTimeline(
            events: [],
            totalSeconds: 0.5,
            tempoScale: 1,
            clicks: [ScoreClick(seconds: 0.1, isDownbeat: true)]
        )
        let beatPlan = ScorePlaybackTimeline(
            events: [],
            totalSeconds: 0.5,
            tempoScale: 1,
            clicks: [ScoreClick(seconds: 0.1, isDownbeat: false)]
        )

        let downbeat = ScorePlayback.renderSamples(
            timeline: downbeatPlan,
            sampleRate: sampleRate,
            metronomeEnabled: true
        )
        let beat = ScorePlayback.renderSamples(
            timeline: beatPlan,
            sampleRate: sampleRate,
            metronomeEnabled: true
        )

        let downbeatCrossings = signChanges(in: downbeat, from: 0.1, to: 0.12, sampleRate: sampleRate)
        let beatCrossings = signChanges(in: beat, from: 0.1, to: 0.12, sampleRate: sampleRate)
        #expect(downbeatCrossings > beatCrossings)
        #expect(downbeatCrossings > 50)
    }

    @Test("循环片段 + 预备拍：拍点不越界且事件相对片段起点")
    func loopRegionWithCountInStaysInBounds() {
        let firstMeasure = ScorePlayback.timeline(
            score: makeScore(),
            loopMeasures: 1...1,
            countInMeasures: 1
        )
        #expect(firstMeasure.leadInSeconds == 4)
        #expect(firstMeasure.totalSeconds == 8)
        #expect(firstMeasure.events.map(\.id) == [0, 1, 2, 3])
        #expect(firstMeasure.events.map(\.startSeconds) == [0, 1, 2, 3])
        #expect(firstMeasure.clicks.count == 8)
        #expect(firstMeasure.clicks.allSatisfy { $0.seconds >= 0 && $0.seconds < firstMeasure.totalSeconds })
        #expect(firstMeasure.clicks.filter { $0.seconds >= firstMeasure.leadInSeconds }.map(\.seconds) == [4, 5, 6, 7])
        #expect(firstMeasure.clicks.filter(\.isDownbeat).map(\.seconds) == [0, 4])

        let secondMeasure = ScorePlayback.timeline(
            score: makeScore(),
            loopMeasures: 2...2,
            countInMeasures: 1
        )
        #expect(secondMeasure.leadInSeconds == 4)
        #expect(secondMeasure.totalSeconds == 6)
        #expect(secondMeasure.events.map(\.id) == [4])
        #expect(secondMeasure.events.first?.startSeconds == 0)
        #expect(secondMeasure.clicks.map(\.seconds) == [0, 1, 2, 3, 4, 5])
        #expect(secondMeasure.clicks.allSatisfy { $0.seconds < secondMeasure.totalSeconds })

        // 渲染不崩溃，长度覆盖含预备拍的总时长。
        let samples = ScorePlayback.renderSamples(timeline: firstMeasure, sampleRate: 8_000)
        #expect(samples.count >= Int(firstMeasure.totalSeconds * 8_000))
    }

    @Test("预备拍期间音符静音，预备拍结束后才发声")
    func countInShiftsRenderedAudio() {
        let plan = ScorePlayback.timeline(score: makeScore(), countInMeasures: 1)
        let samples = ScorePlayback.renderSamples(timeline: plan, sampleRate: 8_000)

        // 预备拍最后一拍 click 在 3.0s 附近，3.2–3.9s 应当安静。
        #expect(peak(of: samples, from: 3.2, to: 3.9) < 0.001)
        // 正曲第一个音从 leadIn（4.0s）才开始。
        #expect(peak(of: samples, from: 4.0, to: 4.1) > 0.05)
    }
}
