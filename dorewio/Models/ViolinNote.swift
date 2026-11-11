import Foundation

/// Scientific pitch notation: F5 is F natural in the fifth octave.
/// This lesson uses fixed-do (F = Fa).
struct ViolinNote: Identifiable, Hashable {
    let id: String
    let solfege: String
    let midi: Int
    let string: ViolinString
    let finger: Int
    let semitonesAboveOpen: Int

    var instruction: String {
        let fingerName: String
        switch finger {
        case 0: fingerName = "空弦"
        case 1: fingerName = "低 1 指（食指）"
        case 2: fingerName = "低 2 指（中指）"
        case 3: fingerName = "3 指（无名指）"
        default: fingerName = "4 指（小指）"
        }
        return "\(string.rawValue) 弦 · \(fingerName)"
    }
}

enum ViolinString: String, CaseIterable, Identifiable {
    case g = "G", d = "D", a = "A", e = "E"

    var id: String { rawValue }

    var openMIDI: Int {
        switch self {
        case .g: return 55
        case .d: return 62
        case .a: return 69
        case .e: return 76
        }
    }
}

struct FingerChoice: Hashable {
    let string: ViolinString
    let finger: Int
}

enum LessonData {
    static let notes: [ViolinNote] = [
        ViolinNote(id: "F5", solfege: "Fa", midi: 77, string: .e, finger: 1, semitonesAboveOpen: 1),
        ViolinNote(id: "E5", solfege: "Mi", midi: 76, string: .e, finger: 0, semitonesAboveOpen: 0),
        ViolinNote(id: "G5", solfege: "Sol", midi: 79, string: .e, finger: 2, semitonesAboveOpen: 3),
        ViolinNote(id: "A5", solfege: "La", midi: 81, string: .e, finger: 3, semitonesAboveOpen: 5),
        ViolinNote(id: "B5", solfege: "Si", midi: 83, string: .e, finger: 4, semitonesAboveOpen: 7),
        ViolinNote(id: "G3", solfege: "Sol", midi: 55, string: .g, finger: 0, semitonesAboveOpen: 0),
        ViolinNote(id: "D4", solfege: "Re", midi: 62, string: .d, finger: 0, semitonesAboveOpen: 0),
        ViolinNote(id: "A4", solfege: "La", midi: 69, string: .a, finger: 0, semitonesAboveOpen: 0)
    ]
}
