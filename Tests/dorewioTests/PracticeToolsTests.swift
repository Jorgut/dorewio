import Testing
import Foundation
@testable import VibratoCore

struct TunerTests {
    @Test("440 Hz 映射为标准 A4")
    func mapsConcertA() {
        let reading = TunerReading(frequency: 440)

        #expect(reading.noteName == "A")
        #expect(reading.octave == 4)
        #expect(abs(reading.cents) < 0.001)
        #expect(reading.isInTune)
    }

    @Test("音高偏差保留正负方向")
    func reportsPitchDirection() {
        #expect(TunerReading(frequency: 445).cents > 0)
        #expect(TunerReading(frequency: 435).cents < 0)
        #expect(!TunerReading(frequency: 450).isInTune)
    }

    @Test("可使用非 440 的校准频率")
    func supportsCalibration() {
        let reading = TunerReading(frequency: 442, concertA: 442)

        #expect(reading.fullName == "A4")
        #expect(abs(reading.cents) < 0.001)
    }
}

struct AudioInputAvailabilityTests {
    @Test("只接受有效且有限的麦克风硬件格式")
    func validatesHardwareInputFormat() {
        #expect(AudioInputAvailability.isUsable(sampleRate: 48_000, channelCount: 1))
        #expect(!AudioInputAvailability.isUsable(sampleRate: 0, channelCount: 1))
        #expect(!AudioInputAvailability.isUsable(sampleRate: .nan, channelCount: 1))
        #expect(!AudioInputAvailability.isUsable(sampleRate: 48_000, channelCount: 0))
    }
}

struct PracticeHistoryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    @Test("今日练习时长累计多个项目")
    func totalsToday() {
        let today = date(2026, 8, 15, 12)
        let records = [
            PracticeRecord(kind: .tuning, startedAt: date(2026, 8, 15, 8), duration: 120),
            PracticeRecord(kind: .vibrato, startedAt: date(2026, 8, 15, 9), duration: 240),
            PracticeRecord(kind: .bow, startedAt: date(2026, 8, 14, 9), duration: 900)
        ]

        #expect(PracticeSummary.seconds(on: today, records: records, calendar: calendar) == 360)
    }

    @Test("连续练习按自然日计算")
    func calculatesCurrentStreak() {
        let today = date(2026, 8, 15, 12)
        let records = [
            PracticeRecord(kind: .bow, startedAt: date(2026, 8, 15, 8), duration: 60),
            PracticeRecord(kind: .rhythm, startedAt: date(2026, 8, 14, 8), duration: 60),
            PracticeRecord(kind: .vibrato, startedAt: date(2026, 8, 13, 8), duration: 60),
            PracticeRecord(kind: .tuning, startedAt: date(2026, 8, 11, 8), duration: 60)
        ]

        #expect(PracticeSummary.streak(asOf: today, records: records, calendar: calendar) == 3)
    }

    @Test("今天尚未练习时从昨天延续连续天数")
    func carriesStreakFromYesterday() {
        let today = date(2026, 8, 15, 12)
        let records = [
            PracticeRecord(kind: .bow, startedAt: date(2026, 8, 14, 8), duration: 60),
            PracticeRecord(kind: .rhythm, startedAt: date(2026, 8, 13, 8), duration: 60)
        ]

        #expect(PracticeSummary.streak(asOf: today, records: records, calendar: calendar) == 2)
    }

    @Test("本周统计排除上周记录")
    func totalsCurrentWeek() {
        let today = date(2026, 8, 15, 12)
        let records = [
            PracticeRecord(kind: .bow, startedAt: date(2026, 8, 10, 8), duration: 300),
            PracticeRecord(kind: .rhythm, startedAt: date(2026, 8, 15, 8), duration: 600),
            PracticeRecord(kind: .vibrato, startedAt: date(2026, 8, 9, 8), duration: 1_200)
        ]

        #expect(PracticeSummary.secondsInWeek(containing: today, records: records, calendar: calendar) == 900)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

struct RhythmScorerTests {
    @Test("均匀点击获得满分并识别速度")
    func scoresSteadyTaps() throws {
        let result = try #require(RhythmScorer.score(tapTimes: [0, 0.5, 1, 1.5, 2], targetBPM: 120))

        #expect(result.score > 99)
        #expect(abs(result.detectedBPM - 120) < 0.01)
        #expect(result.regularity > 0.99)
    }

    @Test("不均匀点击降低得分")
    func penalizesIrregularTaps() throws {
        let result = try #require(RhythmScorer.score(tapTimes: [0, 0.35, 1.1, 1.4, 2.2], targetBPM: 120))

        #expect(result.score < 70)
        #expect(result.regularity < 0.8)
    }

    @Test("不足两次点击时不评分")
    func rejectsInsufficientTaps() {
        #expect(RhythmScorer.score(tapTimes: [0], targetBPM: 80) == nil)
        #expect(RhythmScorer.score(tapTimes: [0, 1], targetBPM: 0) == nil)
    }
}

struct MelodyTranscriberTests {
    @Test("连续相同音高合并为一个音符")
    func groupsStableFrames() {
        let frames = [
            PitchFrame(time: 0, frequency: 440),
            PitchFrame(time: 0.1, frequency: 441),
            PitchFrame(time: 0.2, frequency: 439),
            PitchFrame(time: 0.3, frequency: nil),
            PitchFrame(time: 0.4, frequency: 493.88),
            PitchFrame(time: 0.5, frequency: 494)
        ]

        let notes = MonophonicTranscriber.transcribe(
            frames: frames,
            frameDuration: 0.1,
            minimumNoteDuration: 0.15
        )

        #expect(notes.count == 2)
        #expect(notes[0].midiNote == 69)
        #expect(notes[0].name == "A4")
        #expect(abs(notes[0].duration - 0.3) < 0.001)
        #expect(notes[1].midiNote == 71)
    }

    @Test("短暂噪声音符被过滤")
    func filtersShortNoise() {
        let frames = [
            PitchFrame(time: 0, frequency: 440),
            PitchFrame(time: 0.05, frequency: nil),
            PitchFrame(time: 0.1, frequency: 440),
            PitchFrame(time: 0.2, frequency: 440)
        ]

        let notes = MonophonicTranscriber.transcribe(
            frames: frames,
            frameDuration: 0.05,
            minimumNoteDuration: 0.1
        )

        #expect(notes.count == 1)
        #expect(notes[0].startTime == 0.1)
    }

    @Test("音符可以量化并导出 MusicXML")
    func quantizesAndExportsMusicXML() {
        let notes = [
            TranscribedNote(midiNote: 69, startTime: 0, duration: 0.5),
            TranscribedNote(midiNote: 70, startTime: 0.5, duration: 1)
        ]
        let score = MelodyScore(notes: notes, bpm: 120, title: "练习 & 测试")

        #expect(score.notes[0].durationBeats == 1)
        #expect(score.notes[1].durationBeats == 2)
        #expect(score.musicXML.contains("<step>A</step>"))
        #expect(score.musicXML.contains("<alter>1</alter>"))
        #expect(score.musicXML.contains("练习 &amp; 测试"))
    }
}
