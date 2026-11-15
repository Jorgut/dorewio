import SwiftUI

extension TargetNote {
    var stringHint: String {
        switch name {
        case "G3": "G 弦空弦"
        case "D4": "D 弦空弦"
        case "A4": "A 弦空弦"
        case "E5": "E 弦空弦"
        default: ""
        }
    }
}

enum FeedbackKind { case good, neutral }

struct GuideCard: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PracticePalette.accent)
                        .frame(width: 20, height: 20)
                        .background(PracticePalette.accent.opacity(0.12), in: Circle())
                    Text(step)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .practiceSurface(padding: 16)
    }
}

struct CenterCentsGauge: View {
    let cents: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clamped = max(-50, min(50, cents))
            let x = width / 2 + CGFloat(clamped / 50) * (width / 2 - 12)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 8)
                Capsule()
                    .fill(PracticePalette.success.opacity(0.25))
                    .frame(width: width * 0.10, height: 8)
                    .position(x: width / 2, y: 4)
                Rectangle()
                    .fill(PracticePalette.accent)
                    .frame(width: 3, height: 26)
                    .position(x: x, y: 13)
            }
        }
        .frame(height: 26)
        .accessibilityLabel("中心音准，\(Int(cents.rounded())) 音分")
    }
}

struct VibratoMetrics: View {
    let result: VibratoResult?

    var body: some View {
        HStack(spacing: 10) {
            metric("速度", value: result?.rateHz, unit: "Hz", target: "5–7", good: result.map { (5...7).contains($0.rateHz) } ?? false)
            metric("幅度", value: result?.extentCents, unit: "音分", target: "20–100", good: result.map { (20...100).contains($0.extentCents) } ?? false)
            metric("均匀", value: result.map { $0.regularity * 100 }, unit: "%", target: "≥70", good: result.map { $0.regularity >= 0.7 } ?? false)
        }
    }

    private func metric(_ title: String, value: Double?, unit: String, target: String, good: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.map { String(format: "%.1f", $0) } ?? "--")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(good ? PracticePalette.success : .primary)
            Text("目标 \(target) \(unit)")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .practiceSurface(padding: 10)
        .accessibilityElement(children: .combine)
    }
}

struct FeedbackCard: View {
    let message: String
    let state: FeedbackKind

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: state == .good ? "checkmark.circle.fill" : "lightbulb.fill")
                .foregroundStyle(state == .good ? PracticePalette.success : PracticePalette.accent)
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .practiceSurface(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

struct SimulatedNeckView: View {
    let target: TargetNote
    let currentCents: Double
    let isTouching: Bool
    let onBegin: (TargetNote) -> Void
    let onUpdate: (Double) -> Void
    let onEnd: () -> Void

    @State private var activeNote: TargetNote?
    private let strings = TargetNote.choices

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(strings) { note in
                    VStack(spacing: 2) {
                        Text(note.name).font(.system(size: 12, weight: .bold))
                        Text(note.stringHint).font(.system(size: 7)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 34)
            .background(Color(red: 1.0, green: 0.99, blue: 0.96))

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Color(red: 0.97, green: 0.91, blue: 0.79), Color(red: 0.90, green: 0.79, blue: 0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    ForEach(Array(strings.enumerated()), id: \.element.id) { index, note in
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 2)
                            .offset(x: (CGFloat(index) + 0.5) * width / 4 - 1, y: 4)
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: width / 4, height: height)
                            .offset(x: CGFloat(index) * width / 4)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if activeNote != note {
                                            activeNote = note
                                            onBegin(note)
                                        }
                                        let cents = Double(-value.translation.height / 60) * 100
                                        onUpdate(cents)
                                    }
                                    .onEnded { _ in
                                        activeNote = nil
                                        onEnd()
                                    }
                            )
                    }
                    if let activeNote, let index = strings.firstIndex(of: activeNote) {
                        Circle()
                            .fill(PracticePalette.accent)
                            .frame(width: 42, height: 42)
                            .overlay {
                                Text(activeNote.name).font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                            }
                            .position(
                                x: (CGFloat(index) + 0.5) * width / 4,
                                y: height / 2 + CGFloat(currentCents / 100) * (height / 2 - 30)
                            )
                    }
                    Text(isTouching ? "按住并上下拖动" : "按住琴弦开始")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .position(x: width / 2, y: height - 24)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 0))
        .overlay(Rectangle().stroke(Color.black.opacity(0.08), lineWidth: 1))
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("模拟琴颈，按住任意弦上下拖动练习揉弦")
    }
}


struct ImmersiveNeckView: View {
    let target: TargetNote
    let currentCents: Double
    let isTouching: Bool
    let onBegin: (TargetNote) -> Void
    let onUpdate: (Double) -> Void
    let onEnd: () -> Void

    @State private var activeNote: TargetNote?
    private let strings = TargetNote.choices

    var body: some View {
        GeometryReader { geo in
            let neckWidth = min(max(200, geo.size.width * 0.62), 280)
            let neckHeight = max(300, geo.size.height - 220)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(strings) { note in
                        VStack(spacing: 2) {
                            Text(note.name).font(.system(size: 13, weight: .bold))
                            Text(note.stringHint).font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: neckWidth, height: 38)

                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Color(red: 0.97, green: 0.91, blue: 0.79), Color(red: 0.90, green: 0.79, blue: 0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Rectangle().fill(Color(red: 0.98, green: 0.95, blue: 0.87)).frame(height: 5)
                    ForEach(Array(strings.enumerated()), id: \.element.id) { index, note in
                        Rectangle()
                            .fill(Color.black.opacity(0.38))
                            .frame(width: 2)
                            .offset(x: (CGFloat(index) + 0.5) * neckWidth / 4 - 1, y: 5)
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: neckWidth / 4, height: neckHeight)
                            .offset(x: CGFloat(index) * neckWidth / 4)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if activeNote != note {
                                            activeNote = note
                                            onBegin(note)
                                        }
                                        onUpdate(Double(-value.translation.height / 60) * 100)
                                    }
                                    .onEnded { _ in
                                        activeNote = nil
                                        onEnd()
                                    }
                            )
                    }
                    if let activeNote, let index = strings.firstIndex(of: activeNote) {
                        Circle()
                            .fill(PracticePalette.accent)
                            .frame(width: 54, height: 54)
                            .overlay {
                                VStack(spacing: 1) {
                                    Text(activeNote.name).font(.system(size: 10, weight: .bold))
                                    Text("\(Int(currentCents.rounded()))\u{00A2}").font(.system(size: 7))
                                }
                                .foregroundStyle(.white)
                            }
                            .position(
                                x: (CGFloat(index) + 0.5) * neckWidth / 4,
                                y: neckHeight / 2 + CGFloat(currentCents / 100) * (neckHeight / 2 - 40)
                            )
                    }
                    Text(isTouching ? "保持按住，上下摆动" : "按住任意一根弦开始")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.38), in: Capsule())
                        .position(x: neckWidth / 2, y: neckHeight - 26)
                }
                .frame(width: neckWidth, height: neckHeight)
                .clipShape(.rect(cornerRadius: 0))
                .overlay(Rectangle().stroke(Color.black.opacity(0.10), lineWidth: 1))
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .padding(.top, 84)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("模拟琴颈，按住任意弦上下拖动练习揉弦")
    }
}
