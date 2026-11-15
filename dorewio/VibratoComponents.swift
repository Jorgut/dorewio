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
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
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

struct VibratoNotePosition: Identifiable, Hashable {
    let string: ViolinString
    let finger: Int
    let midiNote: Int
    let name: String
    var isOpen: Bool { finger == 0 }
    var id: String { "\(string.rawValue)-\(finger)" }
}

enum VibratoNoteBook {
    static func positions(advanced: Bool) -> [VibratoNotePosition] {
        let strings: [ViolinString] = [.g, .d, .a, .e]
        var result: [VibratoNotePosition] = []
        for string in strings {
            let openName: String
            let openMIDI: Int
            switch string {
            case .g: openName = "G3"; openMIDI = 55
            case .d: openName = "D4"; openMIDI = 62
            case .a: openName = "A4"; openMIDI = 69
            case .e: openName = "E5"; openMIDI = 76
            }
            result.append(VibratoNotePosition(string: string, finger: 0, midiNote: openMIDI, name: openName))
            for finger in 1...4 {
                guard advanced || finger == 1 else { continue }
                guard let note = firstPositionNote(on: string, finger: finger) else { continue }
                result.append(VibratoNotePosition(string: string, finger: finger, midiNote: note.midi, name: note.name))
            }
        }
        return result
    }

    private static func firstPositionNote(on string: ViolinString, finger: Int) -> (midi: Int, name: String)? {
        switch (string, finger) {
        case (.g, 1): (57, "A3")
        case (.g, 2): (59, "B3")
        case (.g, 3): (60, "C4")
        case (.g, 4): (62, "D4")
        case (.d, 1): (64, "E4")
        case (.d, 2): (65, "F4")
        case (.d, 3): (67, "G4")
        case (.d, 4): (69, "A4")
        case (.a, 1): (71, "B4")
        case (.a, 2): (72, "C5")
        case (.a, 3): (74, "D5")
        case (.a, 4): (76, "E5")
        case (.e, 1): (77, "F5")
        case (.e, 2): (79, "G5")
        case (.e, 3): (81, "A5")
        case (.e, 4): (83, "B5")
        default: nil
        }
    }
}

enum VibratoDotStyle: String, CaseIterable, Identifiable {
    case solid = "实心"
    case dashed = "虚线"
    case hidden = "隐藏"
    var id: Self { self }
}

struct VibratoNeckPanel: View {
    let target: TargetNote
    let currentCents: Double
    let isTouching: Bool
    let advanced: Bool
    let dotStyle: VibratoDotStyle
    let onBegin: (TargetNote) -> Void
    let onUpdate: (Double) -> Void
    let onEnd: () -> Void
    let onTapNote: (VibratoNotePosition) -> Void

    @State private var activeNote: TargetNote?
    private let strings: [ViolinString] = [.g, .d, .a, .e]
    private let positions = VibratoNoteBook.positions(advanced: true)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(strings, id: \.self) { string in
                    VStack(spacing: 1) {
                        Text(string.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.78))
                        Text(targetHint(for: string))
                            .font(.system(size: 7))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 32)

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Color(red: 0.97, green: 0.91, blue: 0.79), Color(red: 0.90, green: 0.79, blue: 0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Rectangle().fill(Color(red: 0.98, green: 0.95, blue: 0.87)).frame(height: 5)

                    ForEach(Array(strings.enumerated()), id: \.element.id) { index, string in
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 2)
                            .offset(x: (CGFloat(index) + 0.5) * width / 4 - 1, y: 5)
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: width / 4, height: height)
                            .offset(x: CGFloat(index) * width / 4)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if activeNote?.name != targetName(for: string) {
                                            activeNote = TargetNote.choices.first { $0.name == targetName(for: string) }
                                            if let note = activeNote { onBegin(note) }
                                        }
                                        onUpdate(Double(-value.translation.height / 60) * 100)
                                    }
                                    .onEnded { _ in
                                        activeNote = nil
                                        onEnd()
                                    }
                            )
                    }

                    if dotStyle != .hidden {
                        ForEach(positions.filter { advanced || $0.finger <= 1 }, id: \.id) { position in
                            dot(position, width: width, height: height)
                                .position(x: (CGFloat(column(of: position.string)) + 0.5) * width / 4,
                                          y: rowY(for: position.finger, height: height))
                        }
                    }

                    if let activeNote {
                        Circle()
                            .fill(PracticePalette.accent)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(activeNote.name).font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                            }
                            .position(
                                x: width / 2,
                                y: height / 2 + CGFloat(currentCents / 100) * (height / 2 - 30)
                            )
                    }

                    Text(isTouching ? "按住并上下拖动" : "按住琴弦开始")
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .position(x: width / 2, y: height - 18)
                }
            }
        }
        .background(Color(red: 1.0, green: 0.99, blue: 0.96))
        .clipShape(.rect(cornerRadius: 0))
        .overlay(Rectangle().stroke(Color.black.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("模拟琴颈，按住任意弦上下拖动练习揉弦")
    }

    private func dot(_ position: VibratoNotePosition, width: CGFloat, height: CGFloat) -> some View {
        Button {
            onTapNote(position)
        } label: {
            Group {
                switch dotStyle {
                case .solid:
                    Circle()
                        .fill(color(for: position))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text(position.name)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        }
                case .dashed:
                    Circle()
                        .strokeBorder(color(for: position).opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .background(Circle().fill(color(for: position).opacity(0.10)))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text(position.name)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(color(for: position).opacity(0.9))
                        }
                case .hidden:
                    EmptyView()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(position.name)，\(position.finger == 0 ? "空弦" : "\(position.finger) 指")")
    }

    private func color(for position: VibratoNotePosition) -> Color {
        switch position.finger {
        case 0: PracticePalette.accent
        case 1: Color(red: 0.70, green: 0.42, blue: 0.00)
        default: Color.secondary.opacity(0.55)
        }
    }

    private func rowY(for finger: Int, height: CGFloat) -> CGFloat {
        let fractions: [Int: CGFloat] = [0: 0.12, 1: 0.30, 2: 0.48, 3: 0.66, 4: 0.84]
        return height * (fractions[finger] ?? 0.5)
    }

    private func column(of string: ViolinString) -> Int {
        switch string {
        case .g: 0; case .d: 1; case .a: 2; case .e: 3
        }
    }

    private func targetHint(for string: ViolinString) -> String {
        switch string {
        case .g: "G3"; case .d: "D4"; case .a: "A4"; case .e: "E5"
        }
    }

    private func targetName(for string: ViolinString) -> String { targetHint(for: string) }
}
