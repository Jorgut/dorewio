import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今天", systemImage: "house.fill")
                }

            LearningLibraryView()
                .tabItem {
                    Label("学习", systemImage: "book.closed.fill")
                }

            PracticeLibraryView()
                .tabItem {
                    Label("训练", systemImage: "metronome.fill")
                }

            NavigationStack {
                ProGate {
                    PracticeStudioView()
                }
            }
                .tabItem {
                    Label("曲目", systemImage: "music.note.list")
                }

            PracticeProgressView()
                .tabItem {
                    Label("进度", systemImage: "chart.bar.fill")
                }
        }
        .tint(PracticePalette.accent)
    }
}

struct VibratoPracticeView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @StateObject private var session = TrainingSession()
    @State private var practiceStartedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PracticeSectionHeader(
                    eyebrow: "左手",
                    title: "稳定、放松、围绕音高中心",
                    detail: "先保持长音，再让左手摆动进入均匀周期"
                )
                TargetSection(session: session)
                TraceSection(session: session)
                MetricsSection(result: session.result)
                FeedbackSection(state: session.state, result: session.result)
                ListenButton(session: session)
            }
            .padding()
        }
        .background(PracticePalette.canvas)
        .navigationTitle("揉弦练习")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: session.isListening) { updatePracticeTimer(isActive: session.isListening) }
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
        history.record(.vibrato, startedAt: startedAt, duration: Date.now.timeIntervalSince(startedAt))
        practiceStartedAt = nil
    }
}

private struct TargetSection: View {
    @ObservedObject var session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("目标音")
                .font(.headline)

            Picker("目标音", selection: $session.targetNote) {
                ForEach(TargetNote.choices) { note in
                    Text(note.name).tag(note)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: session.targetNote) {
                session.resetForTargetChange()
            }

            HStack(alignment: .firstTextBaseline) {
                Text(session.currentFrequency?.formatted(.number.precision(.fractionLength(1))) ?? "--")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Text("Hz")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .practiceSurface()
    }
}

private struct TraceSection: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("实时音高")
                    .font(.headline)
                Spacer()
                Text("±100 音分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            PitchTraceView(samples: session.samples, targetName: session.targetNote.name)
        }
        .practiceSurface()
    }
}

private struct MetricsSection: View {
    let result: VibratoResult?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { metricViews }
            VStack(spacing: 10) { metricViews }
        }
    }

    @ViewBuilder
    private var metricViews: some View {
            PracticeMetric(
                label: "速度",
                value: result?.rateHz.formatted(.number.precision(.fractionLength(1))) ?? "--",
                unit: "Hz"
            )
            PracticeMetric(
                label: "幅度",
                value: result?.extentCents.formatted(.number.precision(.fractionLength(0))) ?? "--",
                unit: "音分"
            )
            PracticeMetric(
                label: "稳定",
                value: result.map { ($0.regularity * 100).formatted(.number.precision(.fractionLength(0))) } ?? "--",
                unit: "%"
            )
    }
}

private struct FeedbackSection: View {
    let state: ListeningState
    let result: VibratoResult?

    var body: some View {
        Label(message, systemImage: icon)
            .font(.body.weight(.medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .practiceSurface()
            .accessibilityLabel("练习反馈：\(message)")
    }

    private var message: String {
        switch state {
        case .permissionDenied: "请在系统设置中允许麦克风访问"
        case .failed: "无法启动麦克风，请稍后重试"
        case .requestingPermission: "正在请求麦克风权限"
        case .idle: "选择目标音，然后开始演奏长音"
        case .listening:
            switch result?.feedback {
            case .good: "揉弦均匀，继续保持"
            case .tooNarrow: "幅度偏窄，放松左手关节"
            case .tooWide: "幅度偏宽，减小手指摆动"
            case .tooSlow: "揉弦偏慢，尝试更连续地摆动"
            case .tooFast: "揉弦偏快，放慢并保持均匀"
            case .irregular: "速度不够均匀，先用慢速重复"
            case .centerFlat: "音准中心偏低"
            case .centerSharp: "音准中心偏高"
            case nil: "保持长音，正在收集揉弦数据"
            }
        }
    }

    private var icon: String {
        result?.feedback == .good ? "checkmark.circle.fill" : "waveform"
    }

    private var color: Color {
        result?.feedback == .good ? PracticePalette.success : .primary
    }
}

private struct ListenButton: View {
    let session: TrainingSession

    var body: some View {
        Button {
            Task { await session.toggleListening() }
        } label: {
            Label(
                session.isListening ? "停止监听" : "开始监听",
                systemImage: session.isListening ? "stop.fill" : "mic.fill"
            )
        }
        .buttonStyle(PressablePrimaryButtonStyle())
        .disabled(session.state == .requestingPermission)
    }
}
