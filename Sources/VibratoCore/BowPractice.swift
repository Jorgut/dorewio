import Foundation

public enum BowExerciseCategory: String, Hashable, Sendable {
    case basic
    case rhythm
}

public enum BowDirection: String, Hashable, Sendable {
    case down
    case up

    public var symbol: String {
        switch self {
        case .down: "↓"
        case .up: "↑"
        }
    }

    public var chineseName: String {
        switch self {
        case .down: "下弓"
        case .up: "上弓"
        }
    }

    fileprivate var opposite: BowDirection {
        self == .down ? .up : .down
    }
}

public struct BowEvent: Hashable, Sendable {
    public let durationBeats: Double
    public let bowFraction: Double
    public let cue: String

    public init(durationBeats: Double, bowFraction: Double, cue: String) {
        self.durationBeats = durationBeats
        self.bowFraction = bowFraction
        self.cue = cue
    }

    public var bowLengthName: String {
        switch bowFraction {
        case 1: "全弓"
        case 0.75: "3/4 弓"
        case 0.5: "半弓"
        case 0.25: "1/4 弓"
        default: "\(bowFraction.formatted(.number.precision(.fractionLength(2)))) 弓"
        }
    }
}

public struct BowExercise: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: BowExerciseCategory
    public let title: String
    public let detail: String
    public let rhythmNotation: String
    public let mnemonic: String
    public let patternNumber: Int?
    public let events: [BowEvent]
    private let declaredBeats: Double?

    public init(
        id: String,
        category: BowExerciseCategory,
        title: String,
        detail: String,
        rhythmNotation: String,
        mnemonic: String,
        patternNumber: Int?,
        events: [BowEvent],
        declaredBeats: Double? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.rhythmNotation = rhythmNotation
        self.mnemonic = mnemonic
        self.patternNumber = patternNumber
        self.events = events
        self.declaredBeats = declaredBeats
    }

    public var eventDuration: Double {
        events.reduce(0) { $0 + $1.durationBeats }
    }

    public var totalBeats: Double {
        declaredBeats ?? eventDuration
    }
}

public struct BowPracticeProgress: Equatable, Sendable {
    public private(set) var eventIndex = 0
    public private(set) var direction = BowDirection.down
    public private(set) var completedCycles = 0
    public let exercise: BowExercise

    public init(exercise: BowExercise) {
        self.exercise = exercise
    }

    public var currentEvent: BowEvent? {
        guard exercise.events.indices.contains(eventIndex) else { return nil }
        return exercise.events[eventIndex]
    }

    public mutating func advance() {
        guard !exercise.events.isEmpty else { return }

        direction = direction.opposite
        if eventIndex == exercise.events.count - 1 {
            eventIndex = 0
            completedCycles += 1
        } else {
            eventIndex += 1
        }
    }

    public mutating func reset() {
        eventIndex = 0
        direction = .down
        completedCycles = 0
    }
}

public enum BowPracticeCurriculum {
    public static let basicExercises: [BowExercise] = [
        BowExercise(
            id: "basic-straight",
            category: .basic,
            title: "弓直练习",
            detail: "两个半弓，中弓停稳；保持弓毛与琴桥平行。",
            rhythmNotation: "1 2 3 / 1 2 3",
            mnemonic: "数 1-2-3，停在中弓",
            patternNumber: nil,
            events: events([3, 3], bows: [0.5, 0.5], cues: ["1-2-3", "1-2-3"]),
            declaredBeats: 6
        ),
        BowExercise(
            id: "basic-tone",
            category: .basic,
            title: "发音练习",
            detail: "全弓往返，换弓时声音不断；弓速和压力保持均匀。",
            rhythmNotation: "1 2 3 4 / 1 2 3 4",
            mnemonic: "1-2-3-4，连续换弓",
            patternNumber: nil,
            events: events([4, 4], bows: [1, 1], cues: ["1-2-3-4", "1-2-3-4"]),
            declaredBeats: 8
        ),
        BowExercise(
            id: "basic-stability",
            category: .basic,
            title: "稳定性练习",
            detail: "把全弓均分为四段，逐段找到相邻弓段，换弓前停稳。",
            rhythmNotation: "1 2 / 1 2 / 1 2 / 1 2",
            mnemonic: "1-2，1-2，1-2，1-2",
            patternNumber: nil,
            events: events(
                [2, 2, 2, 2],
                bows: [0.25, 0.25, 0.25, 0.25],
                cues: ["1-2", "1-2", "1-2", "1-2"]
            ),
            declaredBeats: 8
        ),
        BowExercise(
            id: "basic-speed",
            category: .basic,
            title: "变速练习",
            detail: "全弓往返依次使用 4 拍、2 拍、1 拍，弓长不变，只改变弓速。",
            rhythmNotation: "4 拍 → 2 拍 → 1 拍",
            mnemonic: "慢、稳、快",
            patternNumber: nil,
            events: events(
                [4, 4, 2, 2, 1, 1],
                bows: [1, 1, 1, 1, 1, 1],
                cues: ["4 拍", "4 拍", "2 拍", "2 拍", "1 拍", "1 拍"]
            ),
            declaredBeats: 14
        )
    ]

    public static let rhythmExercises: [BowExercise] = [
        rhythm(
            id: "rhythm-1-normal",
            title: "节奏型一",
            notation: "♪ ♬",
            mnemonic: "da - da-da",
            pattern: 1,
            beats: 1,
            durations: [0.5, 0.25, 0.25],
            bows: [0.5, 0.25, 0.25],
            cues: ["da", "da", "da"]
        ),
        rhythm(
            id: "rhythm-1-slow-2",
            title: "节奏型一 · 慢 2 倍",
            notation: "♩ ♫",
            mnemonic: "daa - da-da",
            pattern: 1,
            beats: 2,
            durations: [1, 0.5, 0.5],
            bows: [1, 0.5, 0.5],
            cues: ["daa", "da", "da"]
        ),
        rhythm(
            id: "rhythm-1-slow-4",
            title: "节奏型一 · 慢 4 倍",
            notation: "二分音符 + 四分音符 + 四分音符",
            mnemonic: "daaa - da-da",
            pattern: 1,
            beats: 4,
            durations: [2, 1, 1],
            bows: [1, 0.5, 0.5],
            cues: ["daaa", "da", "da"]
        ),
        rhythm(
            id: "rhythm-2-normal",
            title: "节奏型二",
            notation: "4 个十六分音符 + 2 个八分音符",
            mnemonic: "di-di-di-di - da-da",
            pattern: 2,
            beats: 2,
            durations: [0.25, 0.25, 0.25, 0.25, 0.5, 0.5],
            bows: [0.25, 0.25, 0.25, 0.25, 0.5, 0.5],
            cues: ["di", "di", "di", "di", "da", "da"]
        ),
        rhythm(
            id: "rhythm-2-slow-2",
            title: "节奏型二 · 慢 2 倍",
            notation: "4 个八分音符 + 2 个四分音符",
            mnemonic: "di-di-di-di - da-da",
            pattern: 2,
            beats: 4,
            durations: [0.5, 0.5, 0.5, 0.5, 1, 1],
            bows: [0.25, 0.25, 0.25, 0.25, 0.5, 0.5],
            cues: ["di", "di", "di", "di", "da", "da"]
        ),
        rhythm(
            id: "rhythm-3-normal",
            title: "节奏型三",
            notation: "附点八分音符 + 十六分音符",
            mnemonic: "da-a - da",
            pattern: 3,
            beats: 1,
            durations: [0.75, 0.25],
            bows: [0.75, 0.25],
            cues: ["da-a", "da"]
        ),
        rhythm(
            id: "rhythm-3-slow-2",
            title: "节奏型三 · 慢 2 倍",
            notation: "附点四分音符 + 八分音符",
            mnemonic: "daa-a - da",
            pattern: 3,
            beats: 2,
            durations: [1.5, 0.5],
            bows: [0.75, 0.25],
            cues: ["daa-a", "da"]
        ),
        rhythm(
            id: "rhythm-4-normal",
            title: "节奏型四 · 切分",
            notation: "十六分 + 八分 + 十六分",
            mnemonic: "da - DA - da",
            pattern: 4,
            beats: 1,
            durations: [0.25, 0.5, 0.25],
            bows: [0.25, 0.5, 0.25],
            cues: ["da", "DA", "da"]
        ),
        rhythm(
            id: "rhythm-5-normal",
            title: "节奏型五 · 三连音",
            notation: "三连八分音符",
            mnemonic: "tri-ple-t",
            pattern: 5,
            beats: 1,
            durations: [1.0 / 3, 1.0 / 3, 1.0 / 3],
            bows: [1.0 / 3, 1.0 / 3, 1.0 / 3],
            cues: ["tri", "ple", "t"]
        )
    ]

    public static let allExercises = basicExercises + rhythmExercises

    private static func rhythm(
        id: String,
        title: String,
        notation: String,
        mnemonic: String,
        pattern: Int,
        beats: Double,
        durations: [Double],
        bows: [Double],
        cues: [String]
    ) -> BowExercise {
        BowExercise(
            id: id,
            category: .rhythm,
            title: title,
            detail: "先念口令，再在空弦上保持每次换弓清楚。",
            rhythmNotation: notation,
            mnemonic: mnemonic,
            patternNumber: pattern,
            events: events(durations, bows: bows, cues: cues),
            declaredBeats: beats
        )
    }

    private static func events(
        _ durations: [Double],
        bows: [Double],
        cues: [String]
    ) -> [BowEvent] {
        zip(zip(durations, bows), cues).map { values, cue in
            BowEvent(durationBeats: values.0, bowFraction: values.1, cue: cue)
        }
    }
}
