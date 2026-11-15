import SwiftUI
import UIKit

// MARK: - Data

struct FingerboardNote: Hashable, Identifiable {
    let string: ViolinString
    let finger: Int
    let midiNote: Int
    let noteName: String

    var id: String { "\(string.rawValue)-\(finger)" }
}

struct FingerboardRow: Identifiable {
    let id: Int
    let label: String
    let notes: [FingerboardNote]
    let isOpenReference: Bool

    var isEnabled: Bool { !isOpenReference }
}

enum FingerboardBook {
    static let supportedPositions = 1...3
    static let allPositions = 1...7

    static let openStrings: [FingerboardNote] = [
        FingerboardNote(string: .g, finger: 0, midiNote: 55, noteName: "G3"),
        FingerboardNote(string: .d, finger: 0, midiNote: 62, noteName: "D4"),
        FingerboardNote(string: .a, finger: 0, midiNote: 69, noteName: "A4"),
        FingerboardNote(string: .e, finger: 0, midiNote: 76, noteName: "E5")
    ]

    private static let firstPosition: [[FingerboardNote]] = [
        [
            FingerboardNote(string: .g, finger: 1, midiNote: 57, noteName: "A3"),
            FingerboardNote(string: .g, finger: 2, midiNote: 59, noteName: "B3"),
            FingerboardNote(string: .g, finger: 3, midiNote: 60, noteName: "C4")
        ],
        [
            FingerboardNote(string: .d, finger: 1, midiNote: 64, noteName: "E4"),
            FingerboardNote(string: .d, finger: 2, midiNote: 65, noteName: "F4"),
            FingerboardNote(string: .d, finger: 3, midiNote: 67, noteName: "G4")
        ],
        [
            FingerboardNote(string: .a, finger: 1, midiNote: 71, noteName: "B4"),
            FingerboardNote(string: .a, finger: 2, midiNote: 72, noteName: "C5"),
            FingerboardNote(string: .a, finger: 3, midiNote: 74, noteName: "D5")
        ],
        [
            FingerboardNote(string: .e, finger: 1, midiNote: 77, noteName: "F5"),
            FingerboardNote(string: .e, finger: 2, midiNote: 79, noteName: "G5"),
            FingerboardNote(string: .e, finger: 3, midiNote: 81, noteName: "A5")
        ]
    ]

    private static let secondPosition: [[FingerboardNote]] = [
        [
            FingerboardNote(string: .g, finger: 1, midiNote: 59, noteName: "B3"),
            FingerboardNote(string: .g, finger: 2, midiNote: 60, noteName: "C4"),
            FingerboardNote(string: .g, finger: 3, midiNote: 62, noteName: "D4")
        ],
        [
            FingerboardNote(string: .d, finger: 1, midiNote: 65, noteName: "F4"),
            FingerboardNote(string: .d, finger: 2, midiNote: 67, noteName: "G4"),
            FingerboardNote(string: .d, finger: 3, midiNote: 69, noteName: "A4")
        ],
        [
            FingerboardNote(string: .a, finger: 1, midiNote: 72, noteName: "C5"),
            FingerboardNote(string: .a, finger: 2, midiNote: 74, noteName: "D5"),
            FingerboardNote(string: .a, finger: 3, midiNote: 76, noteName: "E5")
        ],
        [
            FingerboardNote(string: .e, finger: 1, midiNote: 79, noteName: "G5"),
            FingerboardNote(string: .e, finger: 2, midiNote: 81, noteName: "A5"),
            FingerboardNote(string: .e, finger: 3, midiNote: 83, noteName: "B5")
        ]
    ]

    private static let thirdPosition: [[FingerboardNote]] = [
        [
            FingerboardNote(string: .g, finger: 1, midiNote: 60, noteName: "C4"),
            FingerboardNote(string: .g, finger: 2, midiNote: 62, noteName: "D4"),
            FingerboardNote(string: .g, finger: 3, midiNote: 64, noteName: "E4")
        ],
        [
            FingerboardNote(string: .d, finger: 1, midiNote: 67, noteName: "G4"),
            FingerboardNote(string: .d, finger: 2, midiNote: 69, noteName: "A4"),
            FingerboardNote(string: .d, finger: 3, midiNote: 71, noteName: "B4")
        ],
        [
            FingerboardNote(string: .a, finger: 1, midiNote: 74, noteName: "D5"),
            FingerboardNote(string: .a, finger: 2, midiNote: 76, noteName: "E5"),
            FingerboardNote(string: .a, finger: 3, midiNote: 77, noteName: "F5")
        ],
        [
            FingerboardNote(string: .e, finger: 1, midiNote: 81, noteName: "A5"),
            FingerboardNote(string: .e, finger: 2, midiNote: 83, noteName: "B5"),
            FingerboardNote(string: .e, finger: 3, midiNote: 84, noteName: "C6")
        ]
    ]

    static func fingerRows(for position: Int) -> [[FingerboardNote]] {
        switch position {
        case 1: firstPosition
        case 2: secondPosition
        default: thirdPosition
        }
    }

    static func rows(for position: Int) -> [FingerboardRow] {
        var rows: [FingerboardRow] = []
        rows.append(FingerboardRow(id: 0, label: position == 1 ? "空弦" : "空弦参考",
                                   notes: openStrings, isOpenReference: position > 1))
        for finger in 1...3 {
            let notes = fingerRows(for: position).map { $0[finger - 1] }
            rows.append(FingerboardRow(id: finger, label: "\(finger) 指", notes: notes, isOpenReference: false))
        }
        return rows
    }

    static func questions(for position: Int) -> [FingerboardNote] {
        var notes = fingerRows(for: position).flatMap { $0 }
        if position == 1 {
            notes = openStrings + notes
        }
        return notes
    }
}

// MARK: - View

struct FingerboardPracticeView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @State private var positionNumber = 1
    @State private var questionIndex = 0
    @State private var selected: FingerboardNote?
    @State private var answered = 0
    @State private var correct = 0
    @State private var startedAt = Date.now
    @State private var hasSaved = false
    @State private var showsAdvancedNotice = false
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    @StateObject private var notePlayer = ViolinNotePlayer()

    private var pool: [FingerboardNote] { FingerboardBook.questions(for: positionNumber) }
    private var question: FingerboardNote { pool[questionIndex % pool.count] }
    private var rows: [FingerboardRow] { FingerboardBook.rows(for: positionNumber) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PracticeSectionHeader(
                    eyebrow: "指板 · 第 \(positionNumber) 把位",
                    title: "请找到 \(question.noteName)",
                    detail: "点一下琴弦与手指交叉的位置；上下滑动琴颈可切换把位"
                )

                HStack {
                    Label("第 \(min(answered + 1, 5)) / 5 题", systemImage: "list.number")
                    Spacer()
                    Text("答对 \(correct) 题")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

                GeometryReader { proxy in
                    HStack(alignment: .top, spacing: 10) {
                        leftColumn
                        FingerboardCard(
                            positionNumber: positionNumber,
                            rows: rows,
                            question: question,
                            selected: selected,
                            onAnswer: answer,
                            onSelectPosition: selectPosition,
                            onShift: shiftPosition
                        )
                        .frame(width: max(230, proxy.size.width - 114))
                    }
                }
                .frame(height: 520)

                if let selected {
                    feedback(selected)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PracticePalette.canvas)
        .navigationTitle(positionNumber == 1 ? "第一把位" : "第 \(positionNumber) 把位")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { notePlayer.stop() }
        .alert("进阶把位", isPresented: $showsAdvancedNotice) {
            Button("好", role: .cancel) {}
        } message: {
            Text("第 4–7 把位正在准备中，首版先开放第 1–3 把位。")
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前：第 \(positionNumber) 把位")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PracticePalette.accent)
            Text("\(question.noteName) = \(question.string.rawValue) 弦 · \(question.finger == 0 ? "空弦" : "\(question.finger) 指")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("上下滑动琴颈")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 8)
            Button(answered >= 5 ? "再练一组" : "下一题") { advance() }
                .buttonStyle(PressablePrimaryButtonStyle())
                .font(.subheadline)
            if let selected {
                Text(selected == question ? "位置正确" : "再看一眼：\(question.string.rawValue) 弦 \(question.finger == 0 ? "空弦" : "\(question.finger) 指")")
                    .font(.caption2)
                    .foregroundStyle(selected == question ? PracticePalette.success : PracticePalette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 104, alignment: .leading)
        .frame(minHeight: 500, alignment: .top)
    }

    private func feedback(_ selected: FingerboardNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                selected == question ? "位置正确" : "正确位置：\(question.string.rawValue) 弦 · \(question.finger == 0 ? "空弦" : "\(question.finger) 指")",
                systemImage: selected == question ? "checkmark.circle.fill" : "scope"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected == question ? PracticePalette.success : PracticePalette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .practiceSurface(padding: 14)
    }

    private func answer(_ note: FingerboardNote) {
        guard selected == nil else { return }
        selected = note
        answered += 1
        if note == question { correct += 1 }
        notePlayer.play(midiNote: note.midiNote)
        haptic.impactOccurred(intensity: 0.6)
        if answered == 5 { saveResult() }
    }

    private func advance() {
        if answered >= 5 {
            answered = 0
            correct = 0
            hasSaved = false
            startedAt = .now
        }
        selected = nil
        questionIndex = (questionIndex + 5) % pool.count
    }

    private func shiftPosition(_ delta: Int) {
        let target = min(max(positionNumber + delta, 1), FingerboardBook.supportedPositions.upperBound)
        guard target != positionNumber else { return }
        switchPosition(to: target)
    }

    private func selectPosition(_ number: Int) {
        guard FingerboardBook.supportedPositions.contains(number) else {
            showsAdvancedNotice = true
            return
        }
        guard number != positionNumber else { return }
        switchPosition(to: number)
    }

    private func switchPosition(to number: Int) {
        withAnimation(.snappy(duration: 0.25)) {
            positionNumber = number
            selected = nil
            answered = 0
            correct = 0
            hasSaved = false
            startedAt = .now
            questionIndex = (questionIndex + 1) % max(1, pool.count)
        }
        haptic.impactOccurred(intensity: 0.7)
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

// MARK: - Card

private struct FingerboardCard: View {
    let positionNumber: Int
    let rows: [FingerboardRow]
    let question: FingerboardNote
    let selected: FingerboardNote?
    let onAnswer: (FingerboardNote) -> Void
    let onSelectPosition: (Int) -> Void
    let onShift: (Int) -> Void

    private let rowHeight: CGFloat = 112
    private let headerHeight: CGFloat = 40
    private let gutterWidth: CGFloat = 34
    private let railWidth: CGFloat = 34
    private let strings: [ViolinString] = [.g, .d, .a, .e]

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Text(row.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: gutterWidth, height: rowHeight)
                    }
                }
                .frame(width: gutterWidth)

                GeometryReader { geo in
                    let neckWidth = geo.size.width
                    ZStack(alignment: .topLeading) {
                        LinearGradient(
                            colors: [Color(red: 0.97, green: 0.91, blue: 0.79), Color(red: 0.90, green: 0.79, blue: 0.58)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        Rectangle().fill(Color(red: 0.98, green: 0.95, blue: 0.87)).frame(height: 4)

                        ForEach(0..<4, id: \.self) { index in
                            Rectangle()
                                .fill(Color.black.opacity(0.35))
                                .frame(width: index == 0 ? 3 : 2)
                                .offset(x: (CGFloat(index) + 0.5) * neckWidth / 4 - (index == 0 ? 1.5 : 1), y: 4)
                        }

                        ForEach(1..<rows.count, id: \.self) { row in
                            Rectangle()
                                .fill(Color.black.opacity(0.12))
                                .frame(height: 1)
                                .offset(y: CGFloat(row) * rowHeight)
                        }

                        ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
                            ForEach(strings, id: \.self) { string in
                                if let note = row.notes.first(where: { $0.string == string }) {
                                    noteButton(note: note, row: row)
                                        .position(
                                            x: (CGFloat(stringColumn(string)) + 0.5) * neckWidth / 4,
                                            y: CGFloat(rowIndex) * rowHeight + rowHeight / 2
                                        )
                                }
                            }
                        }
                    }
                }
                .frame(height: CGFloat(rows.count) * rowHeight)

                rail
            }
        }
        .background(Color(red: 1.0, green: 0.99, blue: 0.96))
        .clipShape(.rect(cornerRadius: 0))
        .overlay(Rectangle().stroke(Color.black.opacity(0.08), lineWidth: 1))
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dy = value.translation.height
                    guard abs(dy) > 55, abs(dy) > abs(value.translation.width) else { return }
                    onShift(dy < 0 ? 1 : -1)
                }
        )
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth, height: headerHeight)
            HStack(spacing: 0) {
                ForEach(strings, id: \.self) { string in
                    Text(string.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: headerHeight)
            Color.clear.frame(width: railWidth, height: headerHeight)
        }
        .background(Color(red: 1.0, green: 0.99, blue: 0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
        }
    }

    private var rail: some View {
        VStack(spacing: 10) {
            ForEach(Array(FingerboardBook.allPositions), id: \.self) { number in
                Button {
                    onSelectPosition(number)
                } label: {
                    Text("\(number)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(number == positionNumber ? Color.white : (FingerboardBook.supportedPositions.contains(number) ? Color.primary : Color.secondary.opacity(0.45)))
                        .frame(width: 22, height: 22)
                        .background(
                            number == positionNumber
                                ? PracticePalette.accent
                                : Color.black.opacity(FingerboardBook.supportedPositions.contains(number) ? 0.08 : 0.04),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("第 \(number) 把位")
            }
            Text("把位")
                .font(.system(size: 8))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .padding(.top, 2)
        }
        .frame(width: railWidth)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(Color(red: 1.0, green: 0.99, blue: 0.96))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.black.opacity(0.08)).frame(width: 1)
        }
    }

    private func noteButton(note: FingerboardNote, row: FingerboardRow) -> some View {
        Button {
            onAnswer(note)
        } label: {
            Circle()
                .fill(color(for: note, row: row))
                .frame(width: 46, height: 46)
                .overlay {
                    if selected != nil {
                        Text(note.noteName)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(selected != nil || !row.isEnabled)
        .accessibilityLabel("\(note.string.rawValue) 弦，\(note.finger == 0 ? "空弦" : "\(note.finger) 指")")
    }

    private func color(for note: FingerboardNote, row: FingerboardRow) -> Color {
        guard row.isEnabled else { return Color.black.opacity(0.12) }
        guard let selected else {
            return PracticePalette.accent.opacity(0.82)
        }
        if note == question { return PracticePalette.success }
        if note == selected { return PracticePalette.accent }
        return Color.secondary.opacity(0.30)
    }

    private func stringColumn(_ string: ViolinString) -> Int {
        switch string {
        case .g: 0
        case .d: 1
        case .a: 2
        case .e: 3
        }
    }
}
