import SwiftUI
import UIKit

struct RhythmPracticeView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @State private var bpm = 80.0
    @State private var tapTimes: [Double] = []
    @State private var result: RhythmScore?
    @State private var practiceStartedAt: Date?
    @StateObject private var clicker = MetronomeClickPlayer()
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    @State private var isPlayingTarget = false
    @State private var targetBeat = 0
    @State private var targetTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
                PracticeSectionHeader(
                    eyebrow: "节拍",
                    title: "先让拍点稳定，再把节奏放进弓里",
                    detail: "连续点击四次后开始评分，停顿三秒自动重来"
                )
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("目标速度") {
                        Text("\(Int(bpm)) BPM").fontWeight(.semibold).monospacedDigit()
                    }
                    Slider(value: $bpm, in: 40...180, step: 1)
                        .tint(PracticePalette.accent)
                        .onChange(of: bpm) {
                            reset()
                            if isPlayingTarget { restartTargetTimer() }
                        }
                }
                .practiceSurface(padding: 14)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("目标节拍").font(.headline)
                        Spacer()
                        HStack(spacing: 7) {
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .fill(index == targetBeat && isPlayingTarget ? PracticePalette.accent : Color.black.opacity(0.12))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                    Text("先跟着目标速度点头或打拍，再点击下面的按钮跟上")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(isPlayingTarget ? "停止节拍" : "开始播放目标节拍", systemImage: isPlayingTarget ? "stop.fill" : "play.fill") {
                        isPlayingTarget ? stopTargetMetronome() : startTargetMetronome()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(PracticePalette.accent)
                }
                .practiceSurface(padding: 16)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        metrics
                    }
                    VStack(spacing: 10) {
                        metrics
                    }
                }

                Button(action: registerTap) {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill").font(.largeTitle)
                        Text("跟随节拍点击").font(.headline)
                        Text("已记录 \(tapTimes.count) 次").font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                }
                .buttonStyle(.borderedProminent)
                .tint(PracticePalette.accent)
                .accessibilityHint("连续点击四次以上可获得节奏反馈")

                Label(feedback, systemImage: result == nil ? "metronome" : "chart.bar.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)

        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom) {
            Button("重新开始", systemImage: "arrow.counterclockwise", action: reset)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(PracticePalette.canvas.opacity(0.96))
        }
        .background(PracticePalette.canvas)
        .navigationTitle("节奏练习")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isPlayingTarget) { UIApplication.shared.isIdleTimerDisabled = isPlayingTarget }
        .onDisappear {
            stopTargetMetronome()
            clicker.stop()
            finishPractice()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    @ViewBuilder
    private var metrics: some View {
        metric("得分", result.map { Int($0.score.rounded()).description } ?? "--", "分")
        metric("实际速度", result.map { Int($0.detectedBPM.rounded()).description } ?? "--", "BPM")
        metric("稳定度", result.map { Int(($0.regularity * 100).rounded()).description } ?? "--", "%")
    }

    private func metric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .practiceSurface(padding: 12)
        .accessibilityElement(children: .combine)
    }

    private var feedback: String {
        guard let result else { return "先听目标速度，在稳定拍点上连续点击" }
        if result.score >= 90 { return "节拍稳定，速度也很准确" }
        if result.regularity < 0.75 { return "间隔不够均匀，先放慢速度再试" }
        return result.detectedBPM > bpm ? "节奏偏快" : "节奏偏慢"
    }

    private func registerTap() {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = tapTimes.last, now - last > 3 { reset() }
        practiceStartedAt = practiceStartedAt ?? .now
        tapTimes.append(now)
        if tapTimes.count > 12 { tapTimes.removeFirst() }
        result = RhythmScorer.score(tapTimes: tapTimes, targetBPM: bpm)
        clicker.play(accent: false)
        haptic.impactOccurred(intensity: 0.7)
    }

    private func startTargetMetronome() {
        guard !isPlayingTarget else { return }
        isPlayingTarget = true
        targetBeat = 0
        clicker.start()
        fireTargetBeat()
        restartTargetTimer()
    }

    private func stopTargetMetronome() {
        isPlayingTarget = false
        targetTimer?.invalidate()
        targetTimer = nil
        clicker.stop()
        targetBeat = 0
    }

    private func restartTargetTimer() {
        targetTimer?.invalidate()
        let timer = Timer(timeInterval: 60 / bpm, repeats: true) { _ in
            Task { @MainActor in fireTargetBeat() }
        }
        timer.tolerance = 0.002
        RunLoop.main.add(timer, forMode: .common)
        targetTimer = timer
    }

    private func fireTargetBeat() {
        guard isPlayingTarget else { return }
        clicker.play(accent: targetBeat == 0)
        targetBeat = (targetBeat + 1) % 4
    }

    private func reset() {
        finishPractice()
        tapTimes = []
        result = nil
    }

    private func finishPractice() {
        guard let startedAt = practiceStartedAt else { return }
        history.record(
            .rhythm,
            startedAt: startedAt,
            duration: Date.now.timeIntervalSince(startedAt),
            score: result?.score
        )
        practiceStartedAt = nil
    }
}
