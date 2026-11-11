import Foundation

/// 乐谱指法使用的琴弦。
///
/// 与 App 层的 `ViolinString` 分开命名，避免 App target 与核心包同模块编译时冲突；
/// 四根弦的音高与 App 的 `ViolinString.openMIDI` 保持一致。
public enum FingeringString: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
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

/// 第一把位全部可按下位置的指法建议（含四指与高低半音，供乐谱指法使用）。
public struct ScoreFingering: Hashable, Identifiable, Sendable {
    public let string: FingeringString
    public let semitoneOffset: Int
    public let fingerLabel: String
    public let midiNote: Int

    public var id: String { "\(string.rawValue)-\(semitoneOffset)" }

    /// 例如「D 弦 · 2 指」。
    public var positionDescription: String {
        semitoneOffset == 0 ? "\(string.rawValue) 弦 · 空弦" : "\(string.rawValue) 弦 · \(fingerLabel)指"
    }

    public init(
        string: FingeringString,
        semitoneOffset: Int,
        fingerLabel: String,
        midiNote: Int
    ) {
        self.string = string
        self.semitoneOffset = semitoneOffset
        self.fingerLabel = fingerLabel
        self.midiNote = midiNote
    }
}

/// 把乐谱音高映射到第一把位的弦与指号。
///
/// 采用第一把位标准手型：0 空弦、低 1、1、低 2、2、3、高 3、4，
/// 即每根弦从空弦起 0–7 个半音。同一个音可以由不同弦按出时，
/// 优先选择距离空弦更近（指号更小）的位置，与现有指板测验一致。
public enum FirstPositionFingering {
    /// 半音偏移对应的指号名称，索引即偏移量。
    public static let fingerLabels: [String] = ["0", "低1", "1", "低2", "2", "3", "高3", "4"]

    /// 第一把位从空弦到四指的最大半音跨度。
    public static let maximumOffset = 7

    public static func fingering(forMIDINote midiNote: Int) -> ScoreFingering? {
        var best: ScoreFingering?
        for violinString in FingeringString.allCases {
            let offset = midiNote - violinString.midiNote
            guard offset >= 0, offset <= maximumOffset else { continue }

            let candidate = ScoreFingering(
                string: violinString,
                semitoneOffset: offset,
                fingerLabel: fingerLabels[offset],
                midiNote: midiNote
            )
            if let current = best {
                if offset < current.semitoneOffset { best = candidate }
            } else {
                best = candidate
            }
        }
        return best
    }

    public static func isPlayable(midiNote: Int) -> Bool {
        fingering(forMIDINote: midiNote) != nil
    }
}

/// 统一的音名显示，避免各处重复实现。
public enum PitchName {
    private static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    public static func name(for midiNote: Int) -> String {
        let pitchClass = (midiNote % 12 + 12) % 12
        return "\(names[pitchClass])\(midiNote / 12 - 1)"
    }

    public static func frequency(for midiNote: Int) -> Double {
        440 * pow(2, Double(midiNote - 69) / 12)
    }
}
