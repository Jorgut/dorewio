import Foundation
import Testing
@testable import VibratoCore

struct MusicXMLImportTests {
    private func parse(_ xml: String) throws -> ImportedScore {
        try MusicXMLParser.parse(data: Data(xml.utf8))
    }

    private var singleVoiceScore: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="4.0">
          <work><work-title>小星星片段</work-title></work>
          <part-list><score-part id="P1"><part-name>Violin</part-name></score-part></part-list>
          <part id="P1">
            <measure number="1">
              <attributes>
                <divisions>2</divisions>
                <time><beats>4</beats><beat-type>4</beat-type></time>
                <clef><sign>G</sign><line>2</line></clef>
              </attributes>
              <direction><sound tempo="90"/></direction>
              <note><pitch><step>D</step><octave>4</octave></pitch><duration>2</duration><type>quarter</type></note>
              <note><pitch><step>E</step><octave>4</octave></pitch><duration>2</duration><type>quarter</type></note>
              <note><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch><duration>2</duration><type>quarter</type></note>
              <note><pitch><step>G</step><octave>4</octave></pitch><duration>2</duration><type>quarter</type></note>
            </measure>
            <measure number="2">
              <note><rest/><duration>4</duration><type>half</type></note>
              <note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration><type>quarter</type></note>
              <note><pitch><step>B</step><octave>4</octave></pitch><duration>4</duration><type>half</type></note>
            </measure>
          </part>
        </score-partwise>
        """
    }

    @Test("读取标题、速度、拍位与休止符")
    func parsesTitleTempoAndMeasures() throws {
        let score = try parse(singleVoiceScore)

        #expect(score.title == "小星星片段")
        #expect(score.bpm == 90)
        #expect(score.measureCount == 2)
        #expect(score.measureStartBeats == [0, 4])
        #expect(score.notes.count == 6)
        #expect(score.notes.map(\.midiNote) == [62, 64, 66, 67, 69, 71])
        #expect(score.notes.map(\.startBeat) == [0, 1, 2, 3, 6, 7])
        #expect(score.notes.map(\.durationBeats) == [1, 1, 1, 1, 1, 2])
        #expect(score.endBeat == 9)
    }

    @Test("和弦只保留首个音且不重复推进节拍")
    func keepsFirstChordNoteAndAdvancesOnce() throws {
        let xml = """
        <score-partwise version="4.0">
          <part-list><score-part id="P1"><part-name>Violin</part-name></score-part></part-list>
          <part id="P1"><measure number="1">
            <attributes><divisions>2</divisions></attributes>
            <note><pitch><step>D</step><octave>4</octave></pitch><duration>2</duration></note>
            <note><chord/><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch><duration>2</duration></note>
            <note><pitch><step>G</step><octave>4</octave></pitch><duration>2</duration></note>
          </measure></part>
        </score-partwise>
        """

        let score = try parse(xml)
        #expect(score.notes.map(\.midiNote) == [62, 67])
        #expect(score.notes.map(\.startBeat) == [0, 1])
    }

    @Test("连音线把延音并入前一个同音")
    func mergesTiedNotes() throws {
        let xml = """
        <score-partwise version="4.0">
          <part-list><score-part id="P1"><part-name>Violin</part-name></score-part></part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>2</divisions></attributes>
              <note><pitch><step>D</step><octave>4</octave></pitch><duration>2</duration><tie type="start"/></note>
            </measure>
            <measure number="2">
              <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><tie type="stop"/></note>
            </measure>
          </part>
        </score-partwise>
        """

        let score = try parse(xml)
        #expect(score.notes.count == 1)
        #expect(score.notes[0].durationBeats == 3)
        #expect(score.measureStartBeats == [0, 1])
    }

    @Test("只读取第一个 part 并跳过倚音")
    func readsFirstPartOnly() throws {
        let xml = """
        <score-partwise version="4.0">
          <part-list><score-part id="P1"><part-name>Violin</part-name></score-part></part-list>
          <part id="P1"><measure number="1">
            <attributes><divisions>2</divisions></attributes>
            <note><grace/><pitch><step>B</step><octave>3</octave></pitch></note>
            <note><pitch><step>D</step><octave>4</octave></pitch><duration>2</duration></note>
          </measure></part>
          <part id="P2"><measure number="1">
            <attributes><divisions>2</divisions></attributes>
            <note><pitch><step>A</step><octave>3</octave></pitch><duration>2</duration></note>
          </measure></part>
        </score-partwise>
        """

        let score = try parse(xml)
        #expect(score.notes.map(\.midiNote) == [62])
    }

    @Test("拒绝损坏的压缩包、非 score-partwise 与空乐谱")
    func rejectsUnsupportedInput() {
        #expect(throws: MXLImportError.invalidArchive) {
            try MusicXMLParser.parse(data: Data([0x50, 0x4B, 0x03, 0x04]))
        }
        #expect(throws: MusicXMLImportError.unsupportedFormat) {
            try MusicXMLParser.parse(data: Data("<score-timewise version=\"4.0\"></score-timewise>".utf8))
        }
        #expect(throws: MusicXMLImportError.emptyScore) {
            try MusicXMLParser.parse(data: Data(
                "<score-partwise><part><measure><attributes><divisions>2</divisions></attributes></measure></part></score-partwise>".utf8
            ))
        }
        #expect(throws: MusicXMLImportError.unreadableFile) {
            try MusicXMLParser.parse(data: Data())
        }
    }
}

struct ScoreFingeringTests {
    @Test("空弦与四指映射到第一把位")
    func mapsOpenStringsAndFourFingers() {
        #expect(FirstPositionFingering.fingering(forMIDINote: 55)?.string == .g)
        #expect(FirstPositionFingering.fingering(forMIDINote: 55)?.semitoneOffset == 0)
        #expect(FirstPositionFingering.fingering(forMIDINote: 62)?.string == .d)
        #expect(FirstPositionFingering.fingering(forMIDINote: 69)?.string == .a)
        #expect(FirstPositionFingering.fingering(forMIDINote: 83)?.string == .e)
        #expect(FirstPositionFingering.fingering(forMIDINote: 83)?.fingerLabel == "4")
    }

    @Test("高低半音使用低一指、低二指与高三指")
    func mapsChromaticVariants() {
        #expect(FirstPositionFingering.fingering(forMIDINote: 63)?.fingerLabel == "低1")
        #expect(FirstPositionFingering.fingering(forMIDINote: 66)?.fingerLabel == "2")
        #expect(FirstPositionFingering.fingering(forMIDINote: 60)?.fingerLabel == "3")
        #expect(FirstPositionFingering.fingering(forMIDINote: 61)?.fingerLabel == "高3")
        #expect(FirstPositionFingering.fingering(forMIDINote: 71)?.fingerLabel == "1")
    }

    @Test("同音优先选择更靠近空弦的位置")
    func prefersLowerFingerPosition() {
        // D4 既是 D 空弦也是 G 弦四指，应选择空弦。
        let fingering = FirstPositionFingering.fingering(forMIDINote: 62)
        #expect(fingering?.string == .d)
        #expect(fingering?.semitoneOffset == 0)
        // A4 同理。
        #expect(FirstPositionFingering.fingering(forMIDINote: 69)?.semitoneOffset == 0)
    }

    @Test("超出第一把位的音不给出指法")
    func rejectsOutOfRangeNotes() {
        #expect(FirstPositionFingering.fingering(forMIDINote: 48) == nil)
        #expect(FirstPositionFingering.fingering(forMIDINote: 91) == nil)
        #expect(!FirstPositionFingering.isPlayable(midiNote: 84))
    }
}

struct ScorePlaybackTests {
    private func timeline(
        tempoScale: Double = 1,
        loopMeasures: ClosedRange<Int>? = nil
    ) -> ScorePlaybackTimeline {
        let score = ImportedScore(
            title: "测试",
            bpm: 60,
            notes: [
                ScoreNote(midiNote: 62, startBeat: 0, durationBeats: 1),
                ScoreNote(midiNote: 64, startBeat: 1, durationBeats: 1),
                ScoreNote(midiNote: 66, startBeat: 2, durationBeats: 2)
            ],
            measureStartBeats: [0, 2],
            divisions: 1
        )
        return ScorePlayback.timeline(score: score, tempoScale: tempoScale, loopMeasures: loopMeasures)
    }

    @Test("按 BPM 把拍换算成秒")
    func convertsBeatsToSeconds() {
        let plan = timeline()
        #expect(plan.events.map(\.startSeconds) == [0, 1, 2])
        #expect(plan.events.map(\.durationSeconds) == [1, 1, 2])
        #expect(plan.totalSeconds == 4)
    }

    @Test("降速会把时间轴整体拉长")
    func slowTempoStretchesTimeline() {
        let plan = timeline(tempoScale: 0.5)
        #expect(plan.events.map(\.startSeconds) == [0, 2, 4])
        #expect(plan.totalSeconds == 8)
        #expect(plan.tempoScale == 0.5)
    }

    @Test("片段循环只保留所选小节并重置起点")
    func measureLoopSlicesTimeline() {
        let plan = timeline(loopMeasures: 2...2)
        #expect(plan.events.count == 1)
        #expect(plan.events.first?.id == 2)
        #expect(plan.events.first?.startSeconds == 0)
        #expect(plan.events.first?.durationSeconds == 2)
        #expect(plan.totalSeconds == 2)
    }

    @Test("根据播放时间返回当前音符")
    func resolvesCurrentNote() {
        let plan = timeline()
        #expect(plan.eventIndex(at: -0.1) == nil)
        #expect(plan.eventIndex(at: 0) == 0)
        #expect(plan.eventIndex(at: 1.5) == 1)
        #expect(plan.eventIndex(at: 2.1) == 2)
        #expect(plan.eventIndex(at: 10) == 2)
    }

    @Test("渲染采样长度与内容有效")
    func rendersPlayableSamples() {
        let plan = timeline()
        let samples = ScorePlayback.renderSamples(timeline: plan, sampleRate: 8_000)
        #expect(samples.count >= Int(plan.totalSeconds * 8_000))
        #expect(samples.contains { abs($0) > 0.05 })
        #expect(samples.allSatisfy { abs($0) <= 0.98 })
    }
}
