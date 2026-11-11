import Foundation
import Testing
@testable import VibratoCore

/// 乐谱核心公开 API 的稳定性测试：琴弦枚举、音名、指法与音符模型。
struct FingeringStringTests {
    @Test("琴弦按 G/D/A/E 顺序排列")
    func stringsAreOrderedFromLowToHigh() {
        #expect(FingeringString.allCases.map(\.rawValue) == ["G", "D", "A", "E"])
        #expect(FingeringString.allCases.map(\.id) == FingeringString.allCases)
    }

    @Test("四根空弦使用标准 MIDI 音高")
    func openStringsUseStandardMIDIPitches() {
        #expect(FingeringString.allCases.map(\.midiNote) == [55, 62, 69, 76])
        #expect(FingeringString.g.midiNote == 55)
        #expect(FingeringString.d.midiNote == 62)
        #expect(FingeringString.a.midiNote == 69)
        #expect(FingeringString.e.midiNote == 76)
    }

    @Test("空弦频率与十二平均律一致")
    func openStringFrequenciesMatchEqualTemperament() {
        #expect(abs(FingeringString.a.frequency - 440) < 0.001)
        #expect(abs(FingeringString.g.frequency - 195.998) < 0.01)
        #expect(abs(FingeringString.d.frequency - 293.665) < 0.01)
        #expect(abs(FingeringString.e.frequency - 659.255) < 0.01)
    }
}

struct PitchNameTests {
    @Test("音名使用科学音高记法与升号")
    func formatsScientificPitchNames() {
        // AGENTS.md 约定：F5 是 F 本位（MIDI 77），与 F#5 区分。
        #expect(PitchName.name(for: 77) == "F5")
        #expect(PitchName.name(for: 60) == "C4")
        #expect(PitchName.name(for: 69) == "A4")
        #expect(PitchName.name(for: 61) == "C♯4")
        #expect(PitchName.name(for: 82) == "A♯5")
        #expect(PitchName.name(for: 54) == "F♯3")
    }

    @Test("频率换算以 A4 = 440 Hz 为基准")
    func convertsMIDIToFrequency() {
        #expect(abs(PitchName.frequency(for: 69) - 440) < 0.001)
        #expect(abs(PitchName.frequency(for: 81) - 880) < 0.001)
        #expect(abs(PitchName.frequency(for: 57) - 220) < 0.001)
        #expect(abs(PitchName.frequency(for: 60) - 261.626) < 0.01)
    }
}

struct ScoreFingeringModelTests {
    @Test("指法的 id 与位置描述")
    func describesFingeringPositions() {
        let openD = ScoreFingering(string: .d, semitoneOffset: 0, fingerLabel: "0", midiNote: 62)
        #expect(openD.id == "D-0")
        #expect(openD.positionDescription == "D 弦 · 空弦")

        let highThreeE = ScoreFingering(string: .e, semitoneOffset: 6, fingerLabel: "高3", midiNote: 82)
        #expect(highThreeE.id == "E-6")
        #expect(highThreeE.positionDescription == "E 弦 · 高3指")
    }

    @Test("指法可按值比较并用于集合")
    func fingeringsAreHashableByValue() {
        let first = ScoreFingering(string: .a, semitoneOffset: 1, fingerLabel: "1", midiNote: 70)
        let second = ScoreFingering(string: .a, semitoneOffset: 1, fingerLabel: "1", midiNote: 70)
        let other = ScoreFingering(string: .d, semitoneOffset: 3, fingerLabel: "2", midiNote: 65)

        #expect(first == second)
        #expect(first != other)
        #expect(Set([first, second, other]).count == 2)
    }
}

struct ScoreNoteModelTests {
    @Test("音符默认生成唯一 id")
    func generatesUniqueIdentifiersByDefault() {
        let first = ScoreNote(midiNote: 62, startBeat: 0, durationBeats: 1)
        let second = ScoreNote(midiNote: 62, startBeat: 0, durationBeats: 1)

        #expect(first.id != second.id)
        #expect(first != second)
    }

    @Test("显式 id 与字段会被保留")
    func preservesExplicitFields() {
        let id = UUID()
        let note = ScoreNote(id: id, midiNote: 77, startBeat: 2.5, durationBeats: 0.5)

        #expect(note.id == id)
        #expect(note.midiNote == 77)
        #expect(note.startBeat == 2.5)
        #expect(note.durationBeats == 0.5)
        #expect(note == ScoreNote(id: id, midiNote: 77, startBeat: 2.5, durationBeats: 0.5))
    }
}

struct FirstPositionRangeTests {
    @Test("每根空弦映射到自身且偏移为零")
    func openStringsMapToThemselves() {
        for string in FingeringString.allCases {
            let fingering = FirstPositionFingering.fingering(forMIDINote: string.midiNote)
            #expect(fingering?.string == string)
            #expect(fingering?.semitoneOffset == 0)
            #expect(fingering?.fingerLabel == "0")
        }
    }

    @Test("第一把位覆盖空弦到 E 弦四指的所有半音")
    func coversEverySemitoneInFirstPosition() {
        #expect(FirstPositionFingering.maximumOffset == 7)
        #expect(FirstPositionFingering.fingerLabels.count == 8)
        for midiNote in 55...83 {
            #expect(FirstPositionFingering.isPlayable(midiNote: midiNote))
            #expect(FirstPositionFingering.fingering(forMIDINote: midiNote) != nil)
        }
    }

    @Test("指法偏移、音高与指号保持一致")
    func fingeringsAreInternallyConsistent() {
        for midiNote in 55...83 {
            guard let fingering = FirstPositionFingering.fingering(forMIDINote: midiNote) else {
                Issue.record("MIDI \(midiNote) 应可演奏")
                continue
            }
            #expect(fingering.midiNote == midiNote)
            #expect(fingering.semitoneOffset == midiNote - fingering.string.midiNote)
            #expect(fingering.semitoneOffset >= 0)
            #expect(fingering.semitoneOffset <= FirstPositionFingering.maximumOffset)
            #expect(fingering.fingerLabel == FirstPositionFingering.fingerLabels[fingering.semitoneOffset])
        }
    }
}
