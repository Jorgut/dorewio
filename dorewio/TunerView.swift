import SwiftUI

struct TunerView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @StateObject private var session = TunerSession()
    @State private var practiceStartedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PracticeSectionHeader(
                    eyebrow: "实时音准",
                    title: "让每一个长音落在中心",
                    detail: "先拉空弦，稳定后再调整弦轴或微调器"
                )
                TunerDial(reading: session.reading, isListening: session.isListening)
                StringReference(reading: session.reading)
                CalibrationPanel(concertA: $session.concertA)
                TunerStatus(state: session.state, reading: session.reading)
                TunerListenButton(session: session)
            }
            .padding()
        }
        .background(PracticePalette.canvas)
        .navigationTitle("调音")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: session.isListening) {
            updatePracticeTimer(isActive: session.isListening)
        }
        .onDisappear {
            finishPractice()
            session.stop()
        }
    }

    private func updatePracticeTimer(isActive: Bool) {
        if isActive {
            practiceStartedAt = practiceStartedAt ?? .now
        } else {
            finishPractice()
        }
    }

    private func finishPractice() {
        guard let startedAt = practiceStartedAt else { return }
        history.record(.tuning, startedAt: startedAt, duration: Date.now.timeIntervalSince(startedAt))
        practiceStartedAt = nil
    }
}

private struct TunerDial: View {
    let reading: TunerReading?
    let isListening: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var noteSize = 70.0

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.72)
                    let radius = min(size.width * 0.43, size.height * 0.62)
                    for tick in 0...20 {
                        let angle = Angle.degrees(205 + Double(tick) * 6.5)
                        let outer = point(center: center, radius: radius, angle: angle)
                        let inner = point(center: center, radius: radius - (tick % 5 == 0 ? 15 : 8), angle: angle)
                        var path = Path()
                        path.move(to: inner)
                        path.addLine(to: outer)
                        context.stroke(
                            path,
                            with: .color(tick == 10 ? PracticePalette.accent : .secondary.opacity(0.45)),
                            lineWidth: tick == 10 ? 2 : 1
                        )
                    }

                    let needleAngle = Angle.degrees(270 + normalizedCents * 1.3)
                    var needle = Path()
                    needle.move(to: center)
                    needle.addLine(to: point(center: center, radius: radius - 24, angle: needleAngle))
                    context.stroke(needle, with: .color(readingColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)),
                        with: .color(readingColor)
                    )
                }

                VStack(spacing: 3) {
                    Text(reading?.fullName ?? "--")
                        .font(.system(size: noteSize, weight: .bold, design: .serif))
                        .foregroundStyle(readingColor)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(centsText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .offset(y: 18)
            }
            .frame(height: 230)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)

            HStack {
                Text("♭ 偏低")
                Spacer()
                Text(frequencyText)
                Spacer()
                Text("偏高 ♯")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .practiceSurface(padding: 18)
    }

    private var normalizedCents: Double {
        max(-50, min(50, reading?.cents ?? 0))
    }

    private var readingColor: Color {
        guard isListening, let reading else { return .secondary }
        return reading.isInTune ? PracticePalette.success : PracticePalette.accent
    }

    private var centsText: String {
        guard isListening, let cents = reading?.cents else { return "等待声音" }
        if abs(cents) <= 5 { return "正中音准" }
        return "\(cents >= 0 ? "+" : "")\(cents.formatted(.number.precision(.fractionLength(0)))) 音分"
    }

    private var frequencyText: String {
        guard let frequency = reading?.frequency else { return "-- Hz" }
        return "\(frequency.formatted(.number.precision(.fractionLength(1)))) Hz"
    }

    private var accessibilityText: String {
        guard let reading else { return "调音表，等待声音" }
        return "调音表，\(reading.fullName)，\(centsText)，\(frequencyText)"
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(x: center.x + cos(angle.radians) * radius, y: center.y + sin(angle.radians) * radius)
    }
}

private struct StringReference: View {
    let reading: TunerReading?
    private let strings = ["G3", "D4", "A4", "E5"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(strings, id: \.self) { string in
                VStack(spacing: 5) {
                    Text(String(string.prefix(1))).font(.title3.weight(.semibold))
                    Text(string).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                .foregroundStyle(reading?.fullName == string ? PracticePalette.accent : .primary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(reading?.fullName == string ? PracticePalette.accent.opacity(0.08) : .clear)
            }
        }
        .overlay { RoundedRectangle(cornerRadius: 7).stroke(PracticePalette.hairline) }
        .clipShape(.rect(cornerRadius: 7))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("小提琴空弦 G3、D4、A4、E5")
    }
}

private struct CalibrationPanel: View {
    @Binding var concertA: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("标准音 A4") {
                Text("\(Int(concertA)) Hz").fontWeight(.semibold).monospacedDigit()
            }
            Slider(value: $concertA, in: 430...450, step: 1)
                .tint(PracticePalette.accent)
                .accessibilityLabel("标准音 A4")
                .accessibilityValue("\(Int(concertA)) 赫兹")
        }
        .practiceSurface()
    }
}

private struct TunerStatus: View {
    let state: ListeningState
    let reading: TunerReading?

    var body: some View {
        Label(statusText, systemImage: reading?.isInTune == true ? "checkmark.circle.fill" : "waveform")
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(reading?.isInTune == true ? PracticePalette.success : .primary)
            .contentTransition(.numericText())
    }

    private var statusText: String {
        switch state {
        case .idle: "准备好后，演奏一个稳定的长音"
        case .requestingPermission: "正在请求麦克风权限"
        case .listening: reading?.isInTune == true ? "音准已稳定，可以继续下一根弦" : "保持运弓，慢慢把指针移向中央"
        case .permissionDenied: "请在系统设置中允许麦克风访问"
        case .failed: "麦克风启动失败，请稍后重试"
        }
    }
}

private struct TunerListenButton: View {
    @ObservedObject var session: TunerSession

    var body: some View {
        Button {
            Task { await session.toggle() }
        } label: {
            Label(session.isListening ? "停止调音" : "开始调音", systemImage: session.isListening ? "stop.fill" : "mic.fill")
        }
        .buttonStyle(PressablePrimaryButtonStyle())
        .disabled(session.state == .requestingPermission)
    }
}
