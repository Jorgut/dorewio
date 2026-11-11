import Foundation
import Testing
@testable import VibratoCore

/// MusicXMLParser 的补充边界测试：默认值、速度回退与节拍推进语义。
struct MusicXMLParserEdgeTests {
    private func parse(_ xml: String, fallbackTitle: String = "导入乐谱") throws -> ImportedScore {
        try MusicXMLParser.parse(data: Data(xml.utf8), fallbackTitle: fallbackTitle)
    }

    private func noteXML(
        step: String,
        octave: Int,
        duration: Int? = nil,
        alter: Int? = nil,
        tie: String? = nil
    ) -> String {
        let alterXML = alter.map { "<alter>\($0)</alter>" } ?? ""
        let durationXML = duration.map { "<duration>\($0)</duration>" } ?? ""
        let tieXML = tie.map { "<tie type=\"\($0)\"/>" } ?? ""
        return "<note><pitch><step>\(step)</step>\(alterXML)<octave>\(octave)</octave></pitch>\(durationXML)\(tieXML)</note>"
    }

    private func singleMeasureScore(tempo: String? = nil, notes: String) -> String {
        let direction = tempo.map { "<direction><sound tempo=\"\($0)\"/></direction>" } ?? ""
        return """
        <score-partwise version="4.0">
          <part-list><score-part id="P1"><part-name>Violin</part-name></score-part></part-list>
          <part id="P1"><measure number="1">
            <attributes><divisions>1</divisions></attributes>
            \(direction)
            \(notes)
          </measure></part>
        </score-partwise>
        """
    }

    @Test("没有标题时使用调用方提供的回退标题")
    func usesFallbackTitle() throws {
        let score = try parse(
            singleMeasureScore(notes: noteXML(step: "D", octave: 4, duration: 1)),
            fallbackTitle: "未命名乐谱"
        )
        #expect(score.title == "未命名乐谱")
    }

    @Test("缺少速度与小节信息时回退到 80 BPM 与起点 0")
    func fallsBackToDefaultTempoAndMeasureStart() throws {
        let xml = """
        <score-partwise>
          <part id="P1">
            \(noteXML(step: "D", octave: 4, duration: 2))
          </part>
        </score-partwise>
        """
        let score = try parse(xml)

        #expect(score.bpm == 80)
        #expect(score.divisions == 1)
        #expect(score.measureStartBeats == [0])
        #expect(score.measureCount == 1)
        #expect(score.notes.count == 1)
        #expect(score.notes[0].startBeat == 0)
        #expect(score.notes[0].durationBeats == 2)
    }

    @Test("速度被限制在 20–300 BPM 之间")
    func clampsTempoToSupportedRange() throws {
        let fast = try parse(singleMeasureScore(
            tempo: "500",
            notes: noteXML(step: "D", octave: 4, duration: 1)
        ))
        let slow = try parse(singleMeasureScore(
            tempo: "5",
            notes: noteXML(step: "D", octave: 4, duration: 1)
        ))

        #expect(fast.bpm == 300)
        #expect(slow.bpm == 20)
    }

    @Test("没有 sound tempo 时读取节拍器 per-minute")
    func fallsBackToMetronomeMarking() throws {
        let xml = """
        <score-partwise version="4.0">
          <part id="P1"><measure number="1">
            <attributes><divisions>1</divisions></attributes>
            <direction><direction-type><metronome>
              <beat-unit>quarter</beat-unit>
              <per-minute>72</per-minute>
            </metronome></direction-type></direction>
            \(noteXML(step: "D", octave: 4, duration: 1))
          </measure></part>
        </score-partwise>
        """
        let score = try parse(xml)
        #expect(score.bpm == 72)
    }

    @Test("降号与 F5 本位音高分别换算")
    func mapsFlatAccidentalsAndNaturalF5() throws {
        // F5 是 F 本位（MIDI 77），不能与 F#5（MIDI 78）混淆。
        let score = try parse(singleMeasureScore(notes: [
            noteXML(step: "B", octave: 4, duration: 1, alter: -1),
            noteXML(step: "F", octave: 5, duration: 1)
        ].joined()))

        #expect(score.notes.map(\.midiNote) == [70, 77])
    }

    @Test("不同音高的连音线不会被合并")
    func doesNotMergeTiesAcrossDifferentPitches() throws {
        let xml = """
        <score-partwise version="4.0">
          <part id="P1">
            <measure number="1">
              <attributes><divisions>2</divisions></attributes>
              \(noteXML(step: "D", octave: 4, duration: 2, tie: "start"))
            </measure>
            <measure number="2">
              \(noteXML(step: "E", octave: 4, duration: 2, tie: "stop"))
            </measure>
          </part>
        </score-partwise>
        """
        let score = try parse(xml)

        #expect(score.notes.count == 2)
        #expect(score.notes.map(\.midiNote) == [62, 64])
        #expect(score.notes.map(\.startBeat) == [0, 1])
        #expect(score.notes.map(\.durationBeats) == [1, 1])
    }

    @Test("backup 会把节拍位置回退，支持多声部小节")
    func rewindsBeatPositionWithBackup() throws {
        let xml = """
        <score-partwise version="4.0">
          <part id="P1"><measure number="1">
            <attributes><divisions>2</divisions></attributes>
            \(noteXML(step: "D", octave: 4, duration: 2))
            \(noteXML(step: "E", octave: 4, duration: 2))
            <backup><duration>4</duration></backup>
            \(noteXML(step: "F", octave: 4, duration: 2))
          </measure></part>
        </score-partwise>
        """
        let score = try parse(xml)

        #expect(score.notes.map(\.midiNote) == [62, 64, 65])
        #expect(score.notes.map(\.startBeat) == [0, 1, 0])
        #expect(score.endBeat == 2)
    }

    @Test("时值为零的音符被跳过且不推进节拍")
    func skipsZeroDurationNotes() throws {
        let xml = """
        <score-partwise version="4.0">
          <part id="P1"><measure number="1">
            <attributes><divisions>2</divisions></attributes>
            \(noteXML(step: "D", octave: 4))
            \(noteXML(step: "E", octave: 4, duration: 2))
          </measure></part>
        </score-partwise>
        """
        let score = try parse(xml)

        #expect(score.notes.count == 1)
        #expect(score.notes[0].midiNote == 64)
        #expect(score.notes[0].startBeat == 0)
    }

    @Test("读取不存在的文件抛出 unreadableFile")
    func reportsMissingFileAsUnreadable() {
        let url = URL(fileURLWithPath: "/tmp/dorewio-missing-\(UUID().uuidString).musicxml")
        #expect(throws: MusicXMLImportError.unreadableFile) {
            try MusicXMLParser.parse(contentsOf: url)
        }
    }
}
