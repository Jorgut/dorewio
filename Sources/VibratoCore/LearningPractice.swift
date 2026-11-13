import Foundation

public nonisolated enum ViolinString: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case g = "G"
    case d = "D"
    case a = "A"
    case e = "E"

    public var id: Self { self }

    public var midiNote: Int {
        switch self {
        case .g: 55
        case .d: 62
        case .a: 69
        case .e: 76
        }
    }

    public var frequency: Double {
        440 * pow(2, Double(midiNote - 69) / 12)
    }
}

public struct FingerboardPosition: Hashable, Identifiable, Sendable {
    public let string: ViolinString
    public let finger: Int
    public let midiNote: Int
    public let noteName: String

    public var id: String { "\(string.rawValue)-\(finger)" }

    public init(string: ViolinString, finger: Int, midiNote: Int, noteName: String) {
        self.string = string
        self.finger = finger
        self.midiNote = midiNote
        self.noteName = noteName
    }
}

public enum FirstPositionFingerboard {
    public static let positions: [FingerboardPosition] = [
        FingerboardPosition(string: .g, finger: 0, midiNote: 55, noteName: "G3"),
        FingerboardPosition(string: .g, finger: 1, midiNote: 57, noteName: "A3"),
        FingerboardPosition(string: .g, finger: 2, midiNote: 59, noteName: "B3"),
        FingerboardPosition(string: .g, finger: 3, midiNote: 60, noteName: "C4"),
        FingerboardPosition(string: .d, finger: 0, midiNote: 62, noteName: "D4"),
        FingerboardPosition(string: .d, finger: 1, midiNote: 64, noteName: "E4"),
        FingerboardPosition(string: .d, finger: 2, midiNote: 65, noteName: "F4"),
        FingerboardPosition(string: .d, finger: 3, midiNote: 67, noteName: "G4"),
        FingerboardPosition(string: .a, finger: 0, midiNote: 69, noteName: "A4"),
        FingerboardPosition(string: .a, finger: 1, midiNote: 71, noteName: "B4"),
        FingerboardPosition(string: .a, finger: 2, midiNote: 72, noteName: "C5"),
        FingerboardPosition(string: .a, finger: 3, midiNote: 74, noteName: "D5"),
        FingerboardPosition(string: .e, finger: 0, midiNote: 76, noteName: "E5"),
        FingerboardPosition(string: .e, finger: 1, midiNote: 77, noteName: "F5"),
        FingerboardPosition(string: .e, finger: 2, midiNote: 79, noteName: "G5"),
        FingerboardPosition(string: .e, finger: 3, midiNote: 81, noteName: "A5")
    ]

    public static func position(on string: ViolinString, finger: Int) -> FingerboardPosition? {
        positions.first { $0.string == string && $0.finger == finger }
    }
}

public struct StaffNote: Hashable, Identifiable, Sendable {
    public let midiNote: Int
    public let noteName: String
    public let staffStep: Int

    public var id: Int { midiNote }

    public init(midiNote: Int, noteName: String, staffStep: Int) {
        self.midiNote = midiNote
        self.noteName = noteName
        self.staffStep = staffStep
    }
}

public enum BeginnerNoteBank {
    public static let notes: [StaffNote] =
        FirstPositionFingerboard.positions.map {
            StaffNote(
                midiNote: $0.midiNote,
                noteName: $0.noteName,
                staffStep: diatonicStep(fromMIDINote: $0.midiNote)
            )
        }

    private static func diatonicStep(fromMIDINote midiNote: Int) -> Int {
        let naturalSemitones = [0, 2, 4, 5, 7, 9, 11]
        let pitchClass = (midiNote % 12 + 12) % 12
        let octave = midiNote / 12 - 1
        let letterIndex = naturalSemitones.firstIndex(of: pitchClass) ?? 0
        let referenceC4 = 4 * 7
        return octave * 7 + letterIndex - referenceC4
    }
}

public enum LearningSkill: String, CaseIterable, Hashable, Sendable {
    case sightReading
    case fingerboard
    case rhythm
    case earTraining

    public var practiceKind: PracticeKind {
        switch self {
        case .sightReading: .sightReading
        case .fingerboard: .fingerboard
        case .rhythm: .rhythm
        case .earTraining: .earTraining
        }
    }
}

public struct LearningTask: Hashable, Identifiable, Sendable {
    public let skill: LearningSkill
    public let minutes: Int
    public var id: LearningSkill { skill }

    public init(skill: LearningSkill, minutes: Int) {
        self.skill = skill
        self.minutes = minutes
    }
}

public enum NoInstrumentCourse {
    public static let tasks = [
        LearningTask(skill: .sightReading, minutes: 2),
        LearningTask(skill: .fingerboard, minutes: 3),
        LearningTask(skill: .rhythm, minutes: 3),
        LearningTask(skill: .earTraining, minutes: 2)
    ]
}

public struct LearningProgressSummary: Hashable, Sendable {
    public let completedSessions: Int
    public let averageScore: Double?
}

public enum LearningProgress {
    public static func summary(
        for skill: LearningSkill,
        records: [PracticeRecord]
    ) -> LearningProgressSummary {
        let matching = records.filter { $0.kind == skill.practiceKind }
        let scores = matching.compactMap(\.score)
        let average = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        return LearningProgressSummary(completedSessions: matching.count, averageScore: average)
    }
}
