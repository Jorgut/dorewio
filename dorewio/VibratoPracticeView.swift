import SwiftUI
import UIKit

enum VibratoMode: String, CaseIterable, Identifiable {
    case withViolin = "有琴"
    case withoutViolin = "无琴"
    var id: Self { self }
}

@MainActor
final class VibratoSimulationSession: ObservableObject {
    @Published var target: TargetNote = TargetNote.choices[2]
    @Published private(set) var isTouching = false
    @Published private(set) var samples: [PitchSample] = []
    @Published private(set) var result: VibratoResult?
    @Published private(set) var currentCents: Double = 0

    private let engine = VibratoTouchEngine()
    private let analyzer = VibratoAnalyzer()
    private var startedAt: TimeInterval?

    func begin() {
        guard !isTouching else { return }
        isTouching = true
        samples = []
        result = nil
        currentCents = 0
        startedAt = ProcessInfo.processInfo.systemUptime
        engine.start(baseFrequency: target.frequency)
        append(cents: 0)
    }

    func update(cents: Double) {
        guard isTouching else { return }
        let clamped = max(-100, min(100, cents))
        currentCents = clamped
        engine.setCents(clamped)
        append(cents: clamped)
        result = analyzer.analyze(samples: samples)
    }

    func end() {
        guard isTouching else { return }
        engine.stop()
        isTouching = false
        result = analyzer.analyze(samples: samples)
        startedAt = nil
    }

    func reset() {
        engine.stop()
        isTouching = false
        samples = []
        result = nil
        currentCents = 0
        startedAt = nil
    }

    private func append(cents: Double) {
        guard let startedAt else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        samples.append(PitchSample(time: elapsed, centsFromTarget: cents))
        samples.removeAll { elapsed - $0.time > 3 }
        if samples.count > 400 { samples.removeFirst(samples.count - 400) }
    }
}

struct VibratoPracticeView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @StateObject private var session = TrainingSession()
    @StateObject private var simulation = VibratoSimulationSession()
    @StateObject private var notePlayer = ViolinNotePlayer()
    @State private var mode: VibratoMode
    @State private var practiceStartedAt: Date?
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)

    init() {
        _mode = State(initialValue: CommandLine.arguments.contains("-vibratoNoInstrument") ? .withoutViolin : .withViolin)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PracticeSectionHeader(
                    eyebrow: "左手 · 揉弦",
                    title: "先拉准长音，再开始揉弦",
                    detail: "揉弦是左手在指板上均匀地前后摆动，让音高围绕中心轻微波动"
                )

                Picker("练习方式", selection: $mode) {
                    ForEach(VibratoMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) {
                    stopAll()
                }

                if mode == .withViolin {
                    withViolinContent
                } else {
                    withoutViolinContent
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PracticePalette.canvas)
        .navigationTitle("揉弦练习")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopAll() }
    }

    // MARK: 有琴

    private var withViolinContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GuideCard(steps: [
                "选目标音：先选一根空弦，不用按指",
                "拉准长音：让音准指针进入绿色区域，稳定 2 秒",
                "开始揉弦：手腕放松，前后均匀摆动"
            ])

            targetCard(
                selected: $session.targetNote,
                frequency: session.targetNote.frequency,
                onChange: { session.resetForTargetChange() }
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("中心音准").font(.headline)
                    Spacer()
                    Text(centerOffsetText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(centerColor)
                }
                CenterCentsGauge(cents: currentCents)
                HStack(spacing: 16) {
                    Text("偏低 -50")
                    Spacer()
                    Text("准")
                    Spacer()
                    Text("偏高 +50")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .practiceSurface(padding: 16)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("实时音高").font(.headline)
                    Spacer()
                    Text("最近 3 秒").font(.caption).foregroundStyle(.secondary)
                }
                PitchTraceView(samples: session.samples, targetName: session.targetNote.name)
            }
            .practiceSurface(padding: 16)

            VibratoMetrics(result: session.result)

            FeedbackCard(message: withViolinFeedback, state: feedbackState)

            Button {
                Task { await session.toggleListening() }
            } label: {
                Label(session.isListening ? "停止监听" : "开始监听", systemImage: session.isListening ? "stop.fill" : "mic.fill")
            }
            .buttonStyle(PressablePrimaryButtonStyle())
            .disabled(session.state == .requestingPermission)

            Text("手机放谱架上，麦克风朝向琴身；先拉空弦长音，再开始揉弦。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: session.isListening) { updatePracticeTimer(isActive: session.isListening) }
    }

    // MARK: 无琴

    private var withoutViolinContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GuideCard(steps: [
                "选目标弦：任意一根空弦都可以",
                "按住琴弦：手机上下拖动手指，模拟揉弦动作",
                "看反馈：速度 5–7 Hz、幅度 20–100 音分、均匀 ≥70%"
            ])

            targetCard(
                selected: $simulation.target,
                frequency: simulation.target.frequency,
                onChange: { simulation.reset() }
            )

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("把手机当作琴颈").font(.caption.weight(.semibold))
                    Text("按住任意一根弦上下拖动；松手结束。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(simulation.isTouching ? "正在揉弦" : "等待触摸")
                        .font(.caption)
                        .foregroundStyle(simulation.isTouching ? PracticePalette.accent : .secondary)
                    Spacer()
                }
                .frame(width: 116, alignment: .leading)

                SimulatedNeckView(
                    target: simulation.target,
                    currentCents: simulation.currentCents,
                    isTouching: simulation.isTouching,
                    onBegin: { note in
                        simulation.target = note
                        simulation.begin()
                        haptic.impactOccurred(intensity: 0.7)
                    },
                    onUpdate: { cents in simulation.update(cents: cents) },
                    onEnd: { simulation.end() }
                )
            }
            .frame(height: 500)

            VibratoMetrics(result: simulation.result)

            FeedbackCard(message: withoutViolinFeedback, state: simulationFeedbackState)

            Text("无琴模式用合成的小提琴音色；带上琴后切换到「有琴」，由麦克风分析真实揉弦。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 共用

    private func targetCard(selected: Binding<TargetNote>, frequency: Double, onChange: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("目标音").font(.headline)
            Picker("目标音", selection: selected) {
                ForEach(TargetNote.choices) { note in
                    Text("\(note.name)\n\(note.stringHint)").tag(note)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selected.wrappedValue) { onChange() }

            Text("\(selected.wrappedValue.name) = \(selected.wrappedValue.stringHint)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("试听参考音", systemImage: "speaker.wave.2") {
                    notePlayer.playFrequency(frequency)
                }
                .buttonStyle(.bordered)
                Button("示范揉弦", systemImage: "waveform") {
                    notePlayer.playVibratoDemo(frequency: frequency)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .practiceSurface(padding: 16)
    }

    private var currentCents: Double {
        guard let frequency = session.currentFrequency else { return 0 }
        return 1_200 * log2(frequency / session.targetNote.frequency)
    }

    private var centerOffsetText: String {
        guard session.isListening else { return "等待声音" }
        let cents = currentCents
        if abs(cents) <= 5 { return "正中音准" }
        return "\(cents >= 0 ? "偏高 +" : "偏低 ")\(Int(cents.rounded())) 音分"
    }

    private var centerColor: Color {
        guard session.isListening else { return .secondary }
        return abs(currentCents) <= 5 ? PracticePalette.success : PracticePalette.accent
    }

    private var withViolinFeedback: String {
        switch session.state {
        case .idle: return "选好目标音，点「开始监听」"
        case .requestingPermission: return "正在请求麦克风权限"
        case .permissionDenied: return "请在系统设置中允许麦克风访问"
        case .failed: return "无法启动麦克风，请稍后重试"
        case .listening:
            guard let result = session.result else {
                if abs(currentCents) > 12 {
                    return currentCents > 0 ? "先把长音拉准：现在偏高，放松手腕回到中心" : "先把长音拉准：现在偏低，调整手指角度回到中心"
                }
                return "保持长音，先让音准对准中心，再开始揉弦"
            }
            if abs(result.centerOffsetCents) > 12 {
                return result.centerOffsetCents > 0 ? "中心偏高：放松左手，让音高回到中心" : "中心偏低：手指稍向琴身方向调整"
            }
            if result.regularity < 0.7 { return "摆动不够均匀：先放慢，保持每次幅度一致" }
            if result.extentCents < 20 { return "幅度偏窄：让左手关节多放松一点，摆动稍大" }
            if result.extentCents > 100 { return "幅度偏宽：减小摆动，让音高变化更集中" }
            if result.rateHz < 4 { return "揉弦偏慢：让摆动更连续，目标 5–7 Hz" }
            if result.rateHz > 7.5 { return "揉弦偏快：放慢摆动，先求均匀" }
            return "揉弦均匀，保持这个感觉"
        }
    }

    private var feedbackState: FeedbackKind {
        if case .listening = session.state, let result = session.result, result.feedback == .good { return .good }
        return .neutral
    }

    private var withoutViolinFeedback: String {
        guard !simulation.isTouching else { return "保持按住并上下拖动，感受幅度和速度" }
        guard let result = simulation.result else { return "按住任意一根弦，上下拖动手指开始练习" }
        if abs(result.centerOffsetCents) > 12 {
            return "摆动中心偏离：尽量围绕弦的中点来回"
        }
        if result.regularity < 0.7 { return "摆动不够均匀：放慢，保持每次幅度一致" }
        if result.extentCents < 20 { return "幅度偏窄：手指上下多移动一点" }
        if result.extentCents > 100 { return "幅度偏宽：减小上下移动距离" }
        if result.rateHz < 4 { return "揉弦偏慢：让摆动更连续，目标 5–7 Hz" }
        if result.rateHz > 7.5 { return "揉弦偏快：放慢摆动" }
        return "揉弦均匀，保持这个感觉"
    }

    private var simulationFeedbackState: FeedbackKind {
        simulation.result?.feedback == .good ? .good : .neutral
    }

    private func stopAll() {
        session.stop()
        simulation.reset()
        notePlayer.stop()
        finishPractice()
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
