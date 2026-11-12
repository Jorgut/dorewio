import Foundation
import Testing
@testable import VibratoCore

struct SampleScoreFileTests {
    private func sampleURL(_ name: String) -> URL? {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = packageRoot.appendingPathComponent("outputs").appendingPathComponent(name)
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
}
