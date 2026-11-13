import SwiftUI

struct SightReadingPracticeView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @State private var questionIndex = 4
    @State private var selectedAnswer: String?
    @State private var answered = 0
    @State private var correct = 0
    @State private var startedAt = Date.now
    @State private var hasSaved = false

    private var question: StaffNote {
        BeginnerNoteBank.notes[questionIndex % BeginnerNoteBank.notes.count]
    }

    private var choices: [String] {
        let names = BeginnerNoteBank.notes.map(\.noteName)
        return [
            names[questionIndex % names.count],
            names[(questionIndex + 3) % names.count],
            names[(questionIndex + 6) % names.count],
            names[(questionIndex + 9) % names.count]
        ].sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PracticeSectionHeader(
                    eyebrow: "识谱 1 · 第一把位",
                    title: "这个音是什么？",
                    detail: "先看音符在线或间的位置，再选择音名"
                )
                QuizStatus(answered: answered, correct: correct)
                StaffCard(note: question)
                choiceGrid
                feedback
            }
            .padding()
        }
        .background(PracticePalette.canvas)
        .navigationTitle("基础识谱")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var choiceGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
            ForEach(choices, id: \.self) { choice in
                Button(choice) { answer(choice) }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(choiceColor(choice))
                    .foregroundStyle(selectedAnswer == nil ? Color.primary : Color.white)
                    .clipShape(.rect(cornerRadius: 8))
                    .disabled(selectedAnswer != nil)
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if let selectedAnswer {
            VStack(spacing: 12) {
                Label(
                    selectedAnswer == question.noteName ? "答对了" : "正确答案是 \(question.noteName)",
                    systemImage: selectedAnswer == question.noteName ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(selectedAnswer == question.noteName ? PracticePalette.success : PracticePalette.accent)
                Button(answered >= 5 ? "再练一组" : "下一题") { advance() }
                    .buttonStyle(PressablePrimaryButtonStyle())
            }
            .practiceSurface()
        }
    }

    private func answer(_ answer: String) {
        selectedAnswer = answer
        answered += 1
        if answer == question.noteName { correct += 1 }
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
        questionIndex = (questionIndex + 5) % BeginnerNoteBank.notes.count
    }

    private func saveResult() {
        guard !hasSaved else { return }
        history.record(
            .sightReading,
            startedAt: startedAt,
            duration: max(1, Date.now.timeIntervalSince(startedAt)),
            score: Double(correct) / 5 * 100
        )
        hasSaved = true
    }

    private func choiceColor(_ choice: String) -> Color {
        guard let selectedAnswer else { return PracticePalette.paper }
        if choice == question.noteName { return PracticePalette.success }
        return choice == selectedAnswer ? PracticePalette.accent : Color.secondary.opacity(0.35)
    }
}

private struct StaffCard: View {
    let note: StaffNote

    var body: some View {
        ZStack {
            Canvas { context, size in
                let spacing: CGFloat = 18
                let bottomY: CGFloat = 122
                for index in 0..<5 {
                    let y = bottomY - CGFloat(index) * spacing
                    var line = Path()
                    line.move(to: CGPoint(x: 48, y: y))
                    line.addLine(to: CGPoint(x: size.width - 22, y: y))
                    context.stroke(line, with: .color(.primary.opacity(0.65)), lineWidth: 1)
                }

                let noteY = bottomY - CGFloat(note.staffStep - 2) * spacing / 2
                let noteRect = CGRect(x: size.width * 0.60, y: noteY - 6, width: 18, height: 12)
                context.fill(Path(ellipseIn: noteRect), with: .color(PracticePalette.accent))
                var stem = Path()
                stem.move(to: CGPoint(x: noteRect.maxX - 1, y: noteY))
                stem.addLine(to: CGPoint(x: noteRect.maxX - 1, y: noteY - 38))
                context.stroke(stem, with: .color(PracticePalette.accent), lineWidth: 2)

                let ledgerSteps: [Int]
                if note.staffStep <= 0 {
                    let lowestLine = note.staffStep.isMultiple(of: 2) ? note.staffStep : note.staffStep + 1
                    ledgerSteps = Array(stride(from: 0, through: lowestLine, by: -2))
                } else if note.staffStep >= 12 {
                    let highestLine = note.staffStep.isMultiple(of: 2) ? note.staffStep : note.staffStep - 1
                    ledgerSteps = Array(stride(from: 12, through: highestLine, by: 2))
                } else {
                    ledgerSteps = []
                }
                for step in ledgerSteps {
                    let ledgerY = bottomY - CGFloat(step - 2) * spacing / 2
                    var ledger = Path()
                    ledger.move(to: CGPoint(x: noteRect.minX - 7, y: ledgerY))
                    ledger.addLine(to: CGPoint(x: noteRect.maxX + 7, y: ledgerY))
                    context.stroke(ledger, with: .color(.primary.opacity(0.65)), lineWidth: 1)
                }
            }
            Text("𝄞")
                .font(.system(size: 62))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 54)
        }
        .frame(height: 180)
        .practiceSurface(padding: 8)
        .accessibilityLabel("五线谱上的一个音符")
    }
}

struct QuizStatus: View {
    let answered: Int
    let correct: Int

    var body: some View {
        HStack {
            Label("第 \(min(answered + 1, 5)) / 5 题", systemImage: "list.number")
            Spacer()
            Text("答对 \(correct) 题")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}
