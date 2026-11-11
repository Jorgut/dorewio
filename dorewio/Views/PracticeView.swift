import SwiftUI

struct PracticeView: View {
    @State private var lessonIndex = 0
    @State private var choice: FingerChoice?
    @State private var attempted = false
    @State private var tone = TonePlayer()

    private var current: ViolinNote { LessonData.notes[lessonIndex] }
    private var answer: FingerChoice {
        FingerChoice(string: current.string, finger: current.finger)
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
                    Text("\(lessonIndex + 1) / \(LessonData.notes.count)")
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
                            tone.play(midi: current.midi)
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

                FingerboardView(selected: choice, answer: answer, revealAnswer: correct) { tapped in
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
                            lessonIndex = (lessonIndex + 1) % LessonData.notes.count
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
    }
}

#Preview {
    PracticeView()
}
