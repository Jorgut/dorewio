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
    @State private var isPracticing = false
    @State private var practiceStartedAt: Date?
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    @State private var dotStyle: VibratoDotStyle = .solid
    @State private var advancedDots = false

    init() {
        _mode = State(initialValue: CommandLine.arguments.contains("-vibratoNoInstrument") ? .withoutViolin : .withViolin)
        _isPracticing = State(initialValue: CommandLine.arguments.contains("-vibratoPractice"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isPracticing {
                practiceContent
            } else {
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
                .onChange(of: mode) { stopAll() }

                introContent
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PracticePalette.canvas)
        .navigationTitle("揉弦练习")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isPracticing)
        .toolbar {
            if isPracticing {
                ToolbarItem(placement: .topBarLeading) {
                    Button { endPractice() } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("返回揉弦入口")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("结束") { endPractice() }
                }
            }
        }
        .onChange(of: isPracticing) {
            if !isPracticing { stopAll() }
        }
        .onChange(of: session.isListening) {
            updatePracticeTimer(isActive: session.isListening)
            UIApplication.shared.isIdleTimerDisabled = session.isListening || simulation.isTouching
        }
        .onChange(of: simulation.isTouching) {
            UIApplication.shared.isIdleTimerDisabled = session.isListening || simulation.isTouching
        }
        .onDisappear {
            stopAll()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: 开始前入口

    private var introContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            GuideCard(steps: [
                mode == .withViolin
                    ? "选目标音：先选一根空弦，不用按指"
                    : "选目标弦：任意一根空弦都可以",
                mode == .withViolin
                    ? "拉准长音：让音准指针进入绿色区域，稳定 2 秒"
                    : "按住琴弦：手机上下拖动手指，模拟揉弦动作",
                mode == .withViolin
                    ? "开始揉弦：手腕放松，前后均匀摆动"
                    : "看反馈：速度 5–7 Hz、幅度 20–100 音分、均匀 ≥70%"
            ])

            targetCard

            Button {
                isPracticing = true
                haptic.impactOccurred(intensity: 0.7)
            } label: {
                Label("开始练习", systemImage: "waveform")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressablePrimaryButtonStyle())

            Text(mode == .withViolin
                 ? "进入后点「开始监听」，用真实琴声练习揉弦。"
                 : "进入后按住任意一根弦上下拖动，手机就是琴颈。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode == .withViolin ? "目标音" : "目标弦").font(.headline)
            let binding: Binding<TargetNote> = mode == .withViolin ? $session.targetNote : $simulation.target
            Picker("目标音", selection: binding) {
                ForEach(TargetNote.choices) { note in
                    Text(note.name).tag(note)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: binding.wrappedValue) {
                if mode == .withViolin { session.resetForTargetChange() } else { simulation.reset() }
            }

            Text("\(binding.wrappedValue.name) = \(binding.wrappedValue.stringHint)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("试听参考音", systemImage: "speaker.wave.2") {
                    notePlayer.playFrequency(binding.wrappedValue.frequency)
                }
                .buttonStyle(.bordered)
                Button("示范揉弦", systemImage: "waveform") {
                    notePlayer.playVibratoDemo(frequency: binding.wrappedValue.frequency)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .practiceSurface(padding: 14)
    }

    // MARK: 练习页

    @ViewBuilder
    private var practiceContent: some View {
        if mode == .withViolin {
            withViolinPractice
        } else {
            withoutViolinPractice
        }
    }

    private var withViolinPractice: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("有琴 · \(session.targetNote.name)").font(.headline)
                    Text(session.targetNote.stringHint).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("中心音准").font(.headline)
                    Spacer()
                    Text(centerOffsetText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(centerColor)
                }
                CenterCentsGauge(cents: currentCents)
                HStack {
                    Text("偏低 -50"); Spacer(); Text("准"); Spacer(); Text("偏高 +50")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .practiceSurface(padding: 14)

            VStack(alignment: .leading, spacing: 6) {
                Text("实时音高").font(.headline)
                PitchTraceView(samples: session.samples, targetName: session.targetNote.name)
                    .frame(height: 100)
            }
            .practiceSurface(padding: 14)

            VibratoMetrics(result: session.result)

            FeedbackCard(message: withViolinFeedback, state: feedbackState)

            Button {
                Task { await session.toggleListening() }
            } label: {
                Label(session.isListening ? "停止监听" : "开始监听", systemImage: session.isListening ? "stop.fill" : "mic.fill")
            }
            .buttonStyle(PressablePrimaryButtonStyle())
            .disabled(session.state == .requestingPermission)
        }
    }

    private var withoutViolinPractice: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("无琴 · \(simulation.target.name) 弦").font(.headline)
                    Text("按住琴弦上下拖动；点圆点可听音")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(simulation.isTouching ? "正在揉弦" : "等待触摸")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(simulation.isTouching ? PracticePalette.accent : .secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    metricCard
                    centerGaugeCard
                    dotControlsCard
                    Text(withoutViolinFeedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                VibratoNeckPanel(
                    target: simulation.target,
                    currentCents: simulation.currentCents,
                    isTouching: simulation.isTouching,
                    advanced: advancedDots,
                    dotStyle: dotStyle,
                    onBegin: { note in
                        simulation.target = note
                        simulation.begin()
                        haptic.impactOccurred(intensity: 0.7)
                    },
                    onUpdate: { cents in simulation.update(cents: cents) },
                    onEnd: { simulation.end() },
                    onTapNote: { position in
                        notePlayer.play(midiNote: position.midiNote)
                        haptic.impactOccurred(intensity: 0.4)
                    }
                )
                .frame(width: 200)
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var metricCard: some View {
        VStack(spacing: 0) {
            metricRow("速度", value: simulation.result?.rateHz, target: "5–7 Hz", good: simulation.result.map { (5...7).contains($0.rateHz) } ?? false)
            metricRow("幅度", value: simulation.result?.extentCents, target: "20–100 音分", good: simulation.result.map { (20...100).contains($0.extentCents) } ?? false)
            metricRow("均匀", value: simulation.result.map { $0.regularity * 100 }, target: "≥70%", good: simulation.result.map { $0.regularity >= 0.7 } ?? false)
        }
        .practiceSurface(padding: 10)
    }

    private func metricRow(_ title: String, value: Double?, target: String, good: Bool) -> some View {
        HStack {
            Text(title).font(.caption2).foregroundStyle(.secondary).frame(width: 30, alignment: .leading)
            Text(value.map { String(format: "%.1f", $0) } ?? "--")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(good ? PracticePalette.success : .primary)
                .frame(width: 54, alignment: .leading)
            Text(target).font(.system(size: 8)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Circle()
                .fill(good ? PracticePalette.success : Color.primary.opacity(0.10))
                .frame(width: 6, height: 6)
        }
        .padding(.vertical, 4)
    }

    private var dotControlsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("音位显示", selection: $dotStyle) {
                ForEach(VibratoDotStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            Toggle("进阶 2–4 指", isOn: $advancedDots)
                .font(.caption2)
        }
        .practiceSurface(padding: 8)
    }

    private var centerGaugeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("中心音准").font(.caption.weight(.semibold))
            CenterCentsGauge(cents: simulation.currentCents)
            HStack {
                Text("偏低 -50"); Spacer(); Text("准"); Spacer(); Text("偏高 +50")
            }
            .font(.system(size: 7))
            .foregroundStyle(.secondary)
        }
        .practiceSurface(padding: 10)
    }

    // MARK: 数据

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
        case .idle: return "点「开始监听」，先拉一个稳定的长音"
        case .requestingPermission: return "正在请求麦克风权限"
        case .permissionDenied: return "请在系统设置中允许麦克风访问"
        case .failed: return "无法启动麦克风，请稍后重试"
        case .listening:
            guard let result = session.result else {
                if abs(currentCents) > 12 {
                    return currentCents > 0 ? "先把长音拉准：现在偏高" : "先把长音拉准：现在偏低"
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
        if abs(result.centerOffsetCents) > 12 { return "摆动中心偏离：尽量围绕弦的中点来回" }
        if result.regularity < 0.7 { return "摆动不够均匀：放慢，保持每次幅度一致" }
        if result.extentCents < 20 { return "幅度偏窄：手指上下多移动一点" }
        if result.extentCents > 100 { return "幅度偏宽：减小上下移动距离" }
        if result.rateHz < 4 { return "揉弦偏慢：让摆动更连续，目标 5–7 Hz" }
        if result.rateHz > 7.5 { return "揉弦偏快：放慢摆动" }
        return "揉弦均匀，保持这个感觉"
    }

    private func endPractice() {
        stopAll()
        isPracticing = false
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

#if DEBUG
struct VibratoSelfTestView: View {
    @StateObject private var simulation = VibratoSimulationSession()
    @State private var log = "running"

    var body: some View {
        VStack(spacing: 16) {
            Text("Vibrato simulation self-test").font(.headline)
            Text(log).font(.caption).multilineTextAlignment(.center)
        }
        .task {
            for cycle in 0..<6 {
                simulation.begin()
                for step in 0..<120 {
                    simulation.update(cents: sin(Double(step) / 8) * 40)
                    try? await Task.sleep(for: .milliseconds(12))
                }
                simulation.end()
                log = "cycle \(cycle + 1) done, result: \(simulation.result != nil)"
                try? await Task.sleep(for: .milliseconds(120))
            }
            log = "all cycles completed"
        }
    }
}
#endif
