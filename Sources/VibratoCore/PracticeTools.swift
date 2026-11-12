import Foundation

public enum AudioInputAvailability {
    public nonisolated static func isUsable(sampleRate: Double, channelCount: UInt32) -> Bool {
        sampleRate.isFinite && sampleRate > 0 && channelCount > 0
    }
}

public struct TunerReading: Sendable, Equatable {
    public let frequency: Double
    public let midiNote: Int
    public let noteName: String
    public let octave: Int
    public let cents: Double

    public nonisolated var fullName: String { "\(noteName)\(octave)" }
    public nonisolated var isInTune: Bool { abs(cents) <= 5 }

    public nonisolated init(frequency: Double, concertA: Double = 440) {
        self.frequency = frequency
        let midiValue = 69 + 12 * log2(frequency / concertA)
        midiNote = Int(midiValue.rounded())
        let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        noteName = noteNames[Self.positiveModulo(midiNote, 12)]
        octave = midiNote / 12 - 1
        let targetFrequency = concertA * pow(2, Double(midiNote - 69) / 12)
        cents = 1_200 * log2(frequency / targetFrequency)
    }

    private nonisolated static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        (value % divisor + divisor) % divisor
    }
}

public struct RhythmScore: Sendable, Equatable {
    public let score: Double
    public let detectedBPM: Double
    public let regularity: Double
}

public enum RhythmScorer {
    public nonisolated static func score(tapTimes: [Double], targetBPM: Double) -> RhythmScore? {
        guard tapTimes.count >= 2, targetBPM > 0 else { return nil }

        let intervals = zip(tapTimes.dropFirst(), tapTimes).map(-)
        guard intervals.allSatisfy({ $0 > 0 }) else { return nil }

        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(intervals.count)
        let coefficientOfVariation = sqrt(variance) / mean
        let regularity = max(0, 1 - coefficientOfVariation * 2)
        let targetInterval = 60 / targetBPM
        let tempoAccuracy = max(0, 1 - abs(mean - targetInterval) / targetInterval)
        let combinedScore = 100 * (regularity * 0.7 + tempoAccuracy * 0.3)

        return RhythmScore(
            score: min(100, combinedScore),
            detectedBPM: 60 / mean,
            regularity: regularity
        )
    }
}

public struct PitchFrame: Sendable, Equatable {
    public let time: Double
    public let frequency: Double?

    public nonisolated init(time: Double, frequency: Double?) {
        self.time = time
        self.frequency = frequency
    }
}

public struct TranscribedNote: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let midiNote: Int
    public let startTime: Double
    public let duration: Double

    public nonisolated var name: String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let pitchClass = (midiNote % 12 + 12) % 12
        return "\(names[pitchClass])\(midiNote / 12 - 1)"
    }

    public nonisolated init(id: UUID = UUID(), midiNote: Int, startTime: Double, duration: Double) {
        self.id = id
        self.midiNote = midiNote
        self.startTime = startTime
        self.duration = duration
    }
}

public enum MonophonicTranscriber {
    public nonisolated static func transcribe(
        frames: [PitchFrame],
        frameDuration: Double,
        minimumNoteDuration: Double
    ) -> [TranscribedNote] {
        guard frameDuration > 0 else { return [] }

        var notes: [TranscribedNote] = []
        var activeMidi: Int?
        var activeStart = 0.0
        var activeLastTime = 0.0

        func appendActiveNote() {
            guard let midiNote = activeMidi else { return }
            let duration = activeLastTime - activeStart + frameDuration
            if duration + 0.000_001 >= minimumNoteDuration {
                notes.append(TranscribedNote(
                    midiNote: midiNote,
                    startTime: activeStart,
                    duration: duration
                ))
            }
        }

        for frame in frames.sorted(by: { $0.time < $1.time }) {
            let midi = frame.frequency.flatMap(Self.midiNote)
            if midi == activeMidi, midi != nil {
                activeLastTime = frame.time
            } else {
                appendActiveNote()
                activeMidi = midi
                activeStart = frame.time
                activeLastTime = frame.time
            }
        }
        appendActiveNote()
        return notes
    }

    private nonisolated static func midiNote(for frequency: Double) -> Int? {
        guard frequency > 0 else { return nil }
        return Int((69 + 12 * log2(frequency / 440)).rounded())
    }
}

public nonisolated struct ScoreNote: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let midiNote: Int
    public let startBeat: Double
    public let durationBeats: Double

    public nonisolated init(id: UUID = UUID(), midiNote: Int, startBeat: Double, durationBeats: Double) {
        self.id = id
        self.midiNote = midiNote
        self.startBeat = startBeat
        self.durationBeats = durationBeats
    }
}

public struct MelodyScore: Sendable, Equatable {
    public let notes: [ScoreNote]
    public let bpm: Double
    public let title: String

    public nonisolated init(notes: [TranscribedNote], bpm: Double, title: String) {
        self.bpm = bpm
        self.title = title
        let beatsPerSecond = bpm > 0 ? bpm / 60 : 2
        self.notes = notes.map {
            ScoreNote(
                midiNote: $0.midiNote,
                startBeat: Self.quantize($0.startTime * beatsPerSecond),
                durationBeats: max(0.25, Self.quantize($0.duration * beatsPerSecond))
            )
        }
    }

    public nonisolated var musicXML: String {
        let noteXML = notes.map(Self.musicXMLNote).joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="4.0">
          <work><work-title>\(Self.escapeXML(title))</work-title></work>
          <part-list><score-part id="P1"><part-name>Violin</part-name></score-part></part-list>
          <part id="P1"><measure number="1">
            <attributes><divisions>4</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
            <direction><sound tempo="\(bpm)"/></direction>
        \(noteXML)
          </measure></part>
        </score-partwise>
        """
    }

    private nonisolated static func quantize(_ beats: Double) -> Double {
        (beats * 4).rounded() / 4
    }

    private nonisolated static func musicXMLNote(_ note: ScoreNote) -> String {
        let names: [(step: String, alter: Int?)] = [
            ("C", nil), ("C", 1), ("D", nil), ("D", 1), ("E", nil), ("F", nil),
            ("F", 1), ("G", nil), ("G", 1), ("A", nil), ("A", 1), ("B", nil)
        ]
        let pitch = names[(note.midiNote % 12 + 12) % 12]
        let alter = pitch.alter.map { "<alter>\($0)</alter>" } ?? ""
        let duration = max(1, Int((note.durationBeats * 4).rounded()))
        return "    <note><pitch><step>\(pitch.step)</step>\(alter)<octave>\(note.midiNote / 12 - 1)</octave></pitch><duration>\(duration)</duration></note>"
    }

    private nonisolated static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
