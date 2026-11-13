import SwiftUI

struct FingerboardPracticeView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @State private var questionIndex = 8
    @State private var selectedPosition: FingerboardPosition?
    @State private var answered = 0
    @State private var correct = 0
    @State private var startedAt = Date.now
    @State private var hasSaved = false

    private var question: FingerboardPosition {
        FirstPositionFingerboard.positions[questionIndex % FirstPositionFingerboard.positions.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PracticeSectionHeader(
                    eyebrow: "指板 1 · 第一把位",
                    title: "请找到 \(question.noteName)",
                    detail: "选择它所在的琴弦和手指；0 代表空弦"
                )
                HStack {
                    Label("第 \(min(answered + 1, 5)) / 5 题", systemImage: "list.number")
                    Spacer()
                    Text("答对 \(correct) 题")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                FingerboardGrid(question: question, selected: selectedPosition, action: answer)
                if let selectedPosition {
                    VStack(spacing: 12) {
                        Label(
                            selectedPosition == question ? "位置正确" : "正确位置：\(question.string.rawValue) 弦 · \(question.finger == 0 ? "空弦" : "\(question.finger) 指")",
                            systemImage: selectedPosition == question ? "checkmark.circle.fill" : "scope"
                        )
                        .font(.headline)
                        .foregroundStyle(selectedPosition == question ? PracticePalette.success : PracticePalette.accent)
                        Button(answered >= 5 ? "再练一组" : "下一题") { advance() }
                            .buttonStyle(PressablePrimaryButtonStyle())
                    }
                    .practiceSurface()
                }
            }
            .padding()
        }
        .background(PracticePalette.canvas)
        .navigationTitle("第一把位")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func answer(_ position: FingerboardPosition) {
        guard selectedPosition == nil else { return }
        selectedPosition = position
        answered += 1
        if position == question { correct += 1 }
        if answered == 5 { saveResult() }
    }

    private func advance() {
        if answered >= 5 {
            answered = 0
            correct = 0
            hasSaved = false
            startedAt = .now
        }
        selectedPosition = nil
        questionIndex = (questionIndex + 5) % FirstPositionFingerboard.positions.count
    }

    private func saveResult() {
        guard !hasSaved else { return }
        history.record(
            .fingerboard,
            startedAt: startedAt,
            duration: max(1, Date.now.timeIntervalSince(startedAt)),
            score: Double(correct) / 5 * 100
        )
        hasSaved = true
    }
}

private struct FingerboardGrid: View {
    let question: FingerboardPosition
    let selected: FingerboardPosition?
    let action: (FingerboardPosition) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("琴弦").frame(width: 34)
                ForEach(0..<4) { finger in
                    Text(finger == 0 ? "空" : "\(finger) 指")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(ViolinString.allCases) { violinString in
                HStack(spacing: 8) {
                    Text(violinString.rawValue)
                        .font(.headline)
                        .frame(width: 34)
                    ForEach(0..<4) { finger in
                        if let position = FirstPositionFingerboard.position(on: violinString, finger: finger) {
                            Button { action(position) } label: {
                                Circle()
                                    .fill(color(for: position))
                                    .frame(width: 42, height: 42)
                                    .overlay {
                                        Text(selected == nil ? "" : position.noteName)
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .disabled(selected != nil)
                            .accessibilityLabel("\(violinString.rawValue) 弦，\(finger == 0 ? "空弦" : "\(finger) 指")")
                        }
                    }
                }
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.22))
                        .frame(height: violinString == .e ? 1 : 2)
                        .padding(.leading, 42)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.vertical, 10)
        .practiceSurface()
    }

    private func color(for position: FingerboardPosition) -> Color {
        guard let selected else { return PracticePalette.accent.opacity(0.82) }
        if position == question { return PracticePalette.success }
        if position == selected { return PracticePalette.accent }
        return Color.secondary.opacity(0.32)
    }
}
