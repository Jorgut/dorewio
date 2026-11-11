import Foundation
import Testing
@testable import VibratoCore

struct SampleScoreFileTests {
    private func sampleURL(_ name: String) -> URL? {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = packageRoot.appendingPathComponent("Examples").appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @Test("解析随项目提供的 D 大调音阶样例")
    func parsesDMajorScaleSample() throws {
        guard let url = sampleURL("sample-d-major-scale.musicxml") else { return }
        let score = try MusicXMLParser.parse(contentsOf: url)

        #expect(score.title == "D 大调音阶（第一把位）")
        #expect(score.bpm == 80)
        #expect(score.measureCount == 2)
        #expect(score.notes.map(\.midiNote) == [62, 64, 66, 67, 69, 71, 73, 74])
        #expect(score.notes.allSatisfy { FirstPositionFingering.isPlayable(midiNote: $0.midiNote) })
    }

    @Test("解析小星星样例并给出第一把位指法")
    func parsesTwinkleSampleWithFingerings() throws {
        guard let url = sampleURL("sample-twinkle-d-major.musicxml") else { return }
        let score = try MusicXMLParser.parse(contentsOf: url)

        #expect(score.measureCount == 4)
        #expect(score.notes.count == 14)
        #expect(score.notes.map(\.startBeat).prefix(4) == [0, 1, 2, 3])

        let fingerings = score.notes.map { FirstPositionFingering.fingering(forMIDINote: $0.midiNote) }
        #expect(fingerings.allSatisfy { $0 != nil })
        #expect(fingerings[2]?.string == .a)
        #expect(fingerings[2]?.fingerLabel == "0")
        #expect(fingerings[4]?.string == .a)
        #expect(fingerings[4]?.fingerLabel == "1")
        #expect(fingerings[8]?.string == .d)
        #expect(fingerings[8]?.fingerLabel == "3")

        let timeline = ScorePlayback.timeline(score: score)
        #expect(timeline.events.count == score.notes.count)
        #expect(timeline.totalSeconds > 0)
    }

    @Test("D 大调音阶可生成完整时间轴与第一把位指法")
    func buildsPlayableTimelineForDMajorScale() throws {
        guard let url = sampleURL("sample-d-major-scale.musicxml") else { return }
        let score = try MusicXMLParser.parse(contentsOf: url)

        #expect(score.endBeat == 8)
        #expect(score.measureStartBeats == [0, 4])

        let fingerings = score.notes.map { FirstPositionFingering.fingering(forMIDINote: $0.midiNote) }
        #expect(fingerings.compactMap { $0 }.count == score.notes.count)
        // D4 优先用 D 空弦，C#5 落在 A 弦二把位内的 2 指（4 个半音）。
        #expect(fingerings[0]?.string == .d)
        #expect(fingerings[0]?.fingerLabel == "0")
        #expect(fingerings[6]?.string == .a)
        #expect(fingerings[6]?.semitoneOffset == 4)

        let timeline = ScorePlayback.timeline(score: score)
        #expect(timeline.events.count == 8)
        // 80 BPM 时一拍 0.75 秒，八个四分音符共 6 秒。
        #expect(timeline.events.map(\.startSeconds) == [0, 0.75, 1.5, 2.25, 3, 3.75, 4.5, 5.25])
        #expect(timeline.totalSeconds == 6)
    }

    @Test("压缩的 .mxl 与未压缩的 .musicxml 解析出相同乐谱")
    func mxlAndMusicXMLSamplesAgree() throws {
        guard let mxlURL = sampleURL("sample-twinkle-d-major.mxl"),
              let plainURL = sampleURL("sample-twinkle-d-major.musicxml") else { return }
        let compressed = try MusicXMLParser.parse(contentsOf: mxlURL)
        let plain = try MusicXMLParser.parse(contentsOf: plainURL)

        #expect(compressed.title == plain.title)
        #expect(compressed.bpm == plain.bpm)
        #expect(compressed.divisions == plain.divisions)
        #expect(compressed.measureStartBeats == plain.measureStartBeats)
        #expect(compressed.notes.map(\.midiNote) == plain.notes.map(\.midiNote))
        #expect(compressed.notes.map(\.startBeat) == plain.notes.map(\.startBeat))
        #expect(compressed.notes.map(\.durationBeats) == plain.notes.map(\.durationBeats))
        #expect(compressed.endBeat == plain.endBeat)
    }
}
