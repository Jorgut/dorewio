import SwiftUI
import UIKit

struct MetronomeView: View {
    @StateObject private var clicker = MetronomeClickPlayer()
    @State private var bpm = 80.0
    @State private var beatsPerBar = 4
    @State private var accentFirstBeat = true
    @State private var soundEnabled = true
    @State private var hapticsEnabled = true
    @State private var isRunning = false
    @State private var beat = 0
    @State private var timer: Timer?
    @State private var haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PracticeSectionHeader(
                    eyebrow: "节拍器",
                    title: "把拍点变成身体记忆",
                    detail: "先跟着声音数拍，再慢慢离开声音用内耳感受速度"
                )

                beatIndicator

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("速度")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(bpm)) BPM")
                            .font(.title3.weight(.semibold).monospacedDigit())
                    }
                    Slider(value: $bpm, in: 40...208, step: 1)
                        .tint(PracticePalette.accent)
                        .accessibilityLabel("速度")
                        .accessibilityValue("\(Int(bpm)) BPM")
                    HStack {
                        Button("-5") { bpm = max(40, bpm - 5) }
                        Spacer()
                        Button("+5") { bpm = min(208, bpm + 5) }
                    }
                    .buttonStyle(.bordered)
                    .font(.subheadline.weight(.semibold))
                }
                .practiceSurface(padding: 18)

                VStack(alignment: .leading, spacing: 12) {
                    Text("拍号").font(.headline)
                    Picker("每小节拍数", selection: $beatsPerBar) {
                        Text("2/4").tag(2)
                        Text("3/4").tag(3)
                        Text("4/4").tag(4)
                        Text("6/8").tag(6)
                    }
                    .pickerStyle(.segmented)

                    Toggle("第一拍重音", isOn: $accentFirstBeat)
                    Toggle("声音", isOn: $soundEnabled)
                    Toggle("震动", isOn: $hapticsEnabled)
                }
                .practiceSurface(padding: 18)

                Button {
                    isRunning ? stop() : start()
                } label: {
                    Label(isRunning ? "停止" : "开始", systemImage: isRunning ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressablePrimaryButtonStyle())
                .tint(isRunning ? .red : PracticePalette.accent)
            }
            .padding()
        }
        .background(PracticePalette.canvas)
        .navigationTitle("节拍器")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: bpm) { if isRunning { restartTimer() } }
        .onChange(of: beatsPerBar) { beat = 0 }
        .onChange(of: soundEnabled) { clicker.isEnabled = soundEnabled }
        .onDisappear { stop() }
    }

    private var beatIndicator: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ForEach(0..<beatsPerBar, id: \.self) { index in
                    Circle()
                        .fill(index == beat ? PracticePalette.accent : Color.black.opacity(0.10))
                        .frame(width: index == beat ? 18 : 12, height: index == beat ? 18 : 12)
                        .animation(.snappy(duration: 0.12), value: beat)
                }
            }
            .frame(height: 24)

            Text(isRunning ? "第 \(beat + 1) 拍" : "准备好后开始")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .practiceSurface(padding: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isRunning ? "正在播放，第 \(beat + 1) 拍" : "节拍器未开始")
    }

    private func start() {
        guard !isRunning else { return }
        isRunning = true
        beat = 0
        clicker.isEnabled = soundEnabled
        clicker.start()
        fireBeat()
        restartTimer()
    }

    private func restartTimer() {
        timer?.invalidate()
        let interval = 60 / bpm
        let newTimer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in fireBeat() }
        }
        newTimer.tolerance = 0.002
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func fireBeat() {
        guard isRunning else { return }
        let isAccent = accentFirstBeat && beat == 0
        clicker.play(accent: isAccent)
        if hapticsEnabled {
            haptic.impactOccurred(intensity: isAccent ? 1.0 : 0.55)
        }
        beat = (beat + 1) % beatsPerBar
    }

    private func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
        clicker.stop()
        beat = 0
    }
}
