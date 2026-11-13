import SwiftUI

// MARK: - dorewio first lesson
//
// Ported from the dorewio repository (Models/ViolinNote.swift, Views/FingerboardView.swift,
// Views/PracticeView.swift) so the existing VibratoCoach app can ship the new beginner flow.
// Type names are prefixed with Dorewio to avoid clashing with the existing training types
// (the core already exposes a public ViolinString).

struct DorewioNote: Identifiable, Hashable {
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

struct DorewioFingerChoice: Hashable {
    let string: ViolinString
    let finger: Int
}

enum DorewioLessonData {
    static let notes: [DorewioNote] = [
        DorewioNote(id: "F5", solfege: "Fa", midi: 77, string: .e, finger: 1, semitonesAboveOpen: 1),
        DorewioNote(id: "E5", solfege: "Mi", midi: 76, string: .e, finger: 0, semitonesAboveOpen: 0),
        DorewioNote(id: "G5", solfege: "Sol", midi: 79, string: .e, finger: 2, semitonesAboveOpen: 3),
        DorewioNote(id: "A5", solfege: "La", midi: 81, string: .e, finger: 3, semitonesAboveOpen: 5),
        DorewioNote(id: "B5", solfege: "Si", midi: 83, string: .e, finger: 4, semitonesAboveOpen: 7),
        DorewioNote(id: "G3", solfege: "Sol", midi: 55, string: .g, finger: 0, semitonesAboveOpen: 0),
        DorewioNote(id: "D4", solfege: "Re", midi: 62, string: .d, finger: 0, semitonesAboveOpen: 0),
        DorewioNote(id: "A4", solfege: "La", midi: 69, string: .a, finger: 0, semitonesAboveOpen: 0)
    ]
}

struct DorewioFingerboardView: View {
    let selected: DorewioFingerChoice?
    let answer: DorewioFingerChoice
    let revealAnswer: Bool
    let onTap: (DorewioFingerChoice) -> Void

    private let red = Color(red: 0.74, green: 0.24, blue: 0.20)
    private let fingerSteps = [0, 1, 3, 5, 7]

    var body: some View {
        GeometryReader { geometry in
            let center = geometry.size.width / 2
            let halfSpacing: CGFloat = min(geometry.size.width * 0.095, 39)
            let xs = [center - 3 * halfSpacing, center - halfSpacing,
                      center + halfSpacing, center + 3 * halfSpacing]
            // 指板面板顶部留出空间，让空弦（0）那一排完整落在深色指板内。
            let panelTop: CGFloat = 46
            let nutY: CGFloat = 72
            let neckLength: CGFloat = min(geometry.size.height - 120, 300)
            let panelBottom = nutY + neckLength + 44
            let panelHeight = panelBottom - panelTop

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.14, green: 0.16, blue: 0.18))
                    .frame(width: xs[3] - xs[0] + 55, height: panelHeight)
                    .position(x: center, y: panelTop + panelHeight / 2)

                Text("琴头 · SCROLL ↑")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .position(x: center, y: 9)

                ForEach(Array(ViolinString.allCases.enumerated()), id: \.element.id) { index, string in
                    Text(string.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .position(x: xs[index], y: 30)

                    Path { path in
                        path.move(to: CGPoint(x: xs[index], y: nutY))
                        path.addLine(to: CGPoint(x: xs[index], y: nutY + neckLength))
                    }
                    .stroke(Color(white: 0.85), style: StrokeStyle(lineWidth: CGFloat(3.1 - Double(index) * 0.65)))
                }

                Path { path in
                    path.move(to: CGPoint(x: xs[0] - 23, y: panelTop + 2))
                    path.addLine(to: CGPoint(x: xs[3] + 23, y: panelTop + 2))
                }
                .stroke(.white, lineWidth: 7)

                ForEach(Array(ViolinString.allCases.enumerated()), id: \.element.id) { index, string in
                    ForEach(0..<fingerSteps.count, id: \.self) { finger in
                        let candidate = DorewioFingerChoice(string: string, finger: finger)
                        let y = nutY + noteOffset(fingerSteps[finger], available: neckLength)
                        let isSelected = selected == candidate
                        let isAnswer = revealAnswer && answer == candidate
                        Button {
                            onTap(candidate)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(isAnswer ? Color.green : isSelected ? red : Color.white.opacity(0.18))
                                    .frame(width: 33, height: 33)
                                Circle()
                                    .strokeBorder(.white.opacity(isSelected || isAnswer ? 0.95 : 0.42), lineWidth: 1.5)
                                    .frame(width: 33, height: 33)
                                Text(finger == 0 ? "○" : "\(finger)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(string.rawValue) 弦，\(finger == 0 ? "空弦" : "第 \(finger) 指")")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .position(x: xs[index], y: y)
                    }
                }

                Text("琴身 · BODY ↓")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .position(x: center, y: geometry.size.height - 15)
            }
        }
        .frame(height: 410)
    }

    private func noteOffset(_ semitones: Int, available: CGFloat) -> CGFloat {
        let normalized = 1.0 - pow(2.0, -Double(semitones) / 12.0)
        return CGFloat(normalized / (1.0 - pow(2.0, -7.0 / 12.0))) * (available - 28)
    }
}

struct DorewioLessonView: View {
    @State private var lessonIndex = 0
    @State private var choice: DorewioFingerChoice?
    @State private var attempted = false
    @State private var tone = TonePlayer()

    private var current: DorewioNote { DorewioLessonData.notes[lessonIndex] }
    private var answer: DorewioFingerChoice {
        DorewioFingerChoice(string: current.string, finger: current.finger)
    }
    private var correct: Bool { attempted && choice == answer }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("dorewio.")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("VIOLIN · LESSON 01")
                            .font(.caption.weight(.medium))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(lessonIndex + 1) / \(DorewioLessonData.notes.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("找到这个音符")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(current.id)
                            .font(.system(size: 64, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.8)
                        Text(current.solfege)
                            .font(.title2)
                            .foregroundStyle(Color(red: 0.74, green: 0.24, blue: 0.20))
                        Spacer()
                        Button {
                            tone.play(frequency: PitchName.frequency(for: current.midi))
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .frame(width: 46, height: 46)
                                .background(Color(white: 0.92), in: Circle())
                        }
                        .accessibilityLabel("播放参考音")
                    }
                    Text("在下面的指板上，选择琴弦与手指位置。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 18))

                DorewioFingerboardView(selected: choice, answer: answer, revealAnswer: correct) { tapped in
                    choice = tapped
                    attempted = true
                }

                VStack(alignment: .leading, spacing: 14) {
                    if attempted {
                        Label(correct ? "正确！\(current.instruction)" : "再试一次，看看琴弦和指位。",
                              systemImage: correct ? "checkmark.circle.fill" : "arrow.counterclockwise")
                            .foregroundStyle(correct ? Color.green : Color.primary)
                            .font(.subheadline.weight(.medium))
                    } else {
                        Text("提示：0 = 空弦；1–4 = 左手手指。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if correct {
                        Button {
                            lessonIndex = (lessonIndex + 1) % DorewioLessonData.notes.count
                            choice = nil
                            attempted = false
                        } label: {
                            HStack {
                                Text("下一个音符")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color(red: 0.74, green: 0.24, blue: 0.20), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                Text("第一把位入门示意：琴头在上，琴身在下。圆点是按弦位置，不是琴格；不同手型与升降音会改变指位。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .tint(Color(red: 0.74, green: 0.24, blue: 0.20))
        .background(Color.white)
        .navigationTitle("第一课")
        .navigationBarTitleDisplayMode(.inline)
    }
}
