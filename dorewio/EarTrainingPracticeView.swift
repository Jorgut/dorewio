import SwiftUI

struct EarTrainingPracticeView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @State private var questionIndex = 0
    @State private var selectedAnswer: ViolinString?
    @State private var answered = 0
    @State private var correct = 0
    @State private var startedAt = Date.now
    @State private var hasSaved = false
    @State private var tonePlayer = TonePlayer()

    private var question: ViolinString {
        ViolinString.allCases[questionIndex % ViolinString.allCases.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PracticeSectionHeader(
                    eyebrow: "听辨 1 · 四根空弦",
                    title: "你听到的是哪根弦？",
                    detail: "先听音高，再从 G、D、A、E 中选择"
                )
                QuizStatus(answered: answered, correct: correct)
                Button { playQuestion() } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 42))
                        Text("播放声音").font(.headline)
                        Text("可以反复播放").font(.caption).opacity(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                }
                .buttonStyle(PressablePrimaryButtonStyle())

                HStack(spacing: 9) {
                    ForEach(ViolinString.allCases) { violinString in
                        Button(violinString.rawValue) { answer(violinString) }
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(answerColor(violinString))
                            .foregroundStyle(selectedAnswer == nil ? Color.primary : Color.white)
                            .clipShape(.rect(cornerRadius: 8))
                            .disabled(selectedAnswer != nil)
                            .accessibilityLabel("\(violinString.rawValue) 弦")
                    }
                }

                if let selectedAnswer {
                    VStack(spacing: 12) {
                        Label(
                            selectedAnswer == question ? "听对了，这是 \(question.rawValue) 弦" : "这是 \(question.rawValue) 弦，再听一次记住它",
                            systemImage: selectedAnswer == question ? "checkmark.circle.fill" : "ear.badge.waveform"
                        )
                        .font(.headline)
                        .foregroundStyle(selectedAnswer == question ? PracticePalette.success : PracticePalette.accent)
                        Button(answered >= 5 ? "再练一组" : "下一题") { advance() }
                            .buttonStyle(PressablePrimaryButtonStyle())
                    }
                    .practiceSurface()
                }
            }
            .padding()
        }
        .background(PracticePalette.canvas)
        .navigationTitle("空弦听辨")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { playQuestion() }
        .onDisappear { tonePlayer.stop() }
    }

    private func playQuestion() {
        tonePlayer.play(frequency: question.frequency)
    }

    private func answer(_ answer: ViolinString) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = answer
        answered += 1
        if answer == question { correct += 1 }
        if answered == 5 { saveResult() }
    }

    private func advance() {
        if answered >= 5 {
            answered = 0
            correct = 0
            hasSaved = false
            startedAt = .now
        }
        selectedAnswer = nil
        questionIndex = (questionIndex + 3) % ViolinString.allCases.count
        playQuestion()
    }

    private func saveResult() {
        guard !hasSaved else { return }
        history.record(
            .earTraining,
            startedAt: startedAt,
            duration: max(1, Date.now.timeIntervalSince(startedAt)),
            score: Double(correct) / 5 * 100
        )
        hasSaved = true
    }

    private func answerColor(_ violinString: ViolinString) -> Color {
        guard let selectedAnswer else { return PracticePalette.paper }
        if violinString == question { return PracticePalette.success }
        return violinString == selectedAnswer ? PracticePalette.accent : Color.secondary.opacity(0.35)
    }
}
