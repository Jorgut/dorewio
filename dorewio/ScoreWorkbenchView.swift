import SwiftUI

/// 「曲目」页的乐谱工作台：导入 MusicXML 后按谱发声、显示指法、降速与片段循环。
struct ScoreWorkbench: View {
    @ObservedObject var session: ScorePracticeSession
    let importAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let score = session.score {
                scoreHeader(score)
                noteStrip(score)
                transport
            } else {
                emptyState
            }
        }
    }

    // MARK: - 空状态与导入

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(PracticePalette.accent)
                    .frame(width: 60, height: 60)
                    .background(PracticePalette.accent.opacity(0.10))
                    .clipShape(.rect(cornerRadius: 7))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("导入乐谱，直接跟奏")
                        .font(.title3.weight(.bold))
                    Text("导入单声部 MusicXML / MXL，按谱发声并显示弦与指号")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            Button("导入乐谱（MusicXML / MXL）", systemImage: "folder", action: importAction)
                .buttonStyle(.borderedProminent)
                .tint(PracticePalette.accent)
                .controlSize(.large)

            Text("支持 .mxl（自动解压）、.musicxml 与 .xml 单声部乐谱。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .practiceSurface(padding: 20)
    }

    // MARK: - 乐谱信息

    private func scoreHeader(_ score: ImportedScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("按谱演奏")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PracticePalette.accent)
                    Text(score.title)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    Text("\(score.measureCount) 小节 · \(score.notes.count) 个音 · \(Int(score.bpm.rounded())) BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button("更换乐谱", systemImage: "folder", action: importAction)
                    Button("移除乐谱", systemImage: "xmark.circle", role: .destructive) {
                        session.removeScore()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("乐谱操作")
            }
        }
        .practiceSurface()
    }

    // MARK: - 音符与指法

    private func noteStrip(_ score: ImportedScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("音符与指法")
                    .font(.headline)
                Spacer()
                Text("\(formatTime(session.currentTime)) / \(formatTime(session.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(score.notes.enumerated()), id: \.offset) { index, note in
                            NoteCell(
                                note: note,
                                isCurrent: session.currentNoteIndex == index
                            )
                            .id(index)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: session.currentNoteIndex) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            Text("指法：0 空弦 · 低1/1 · 低2/2 · 3 · 高3 · 4，均为第一把位")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if session.outOfRangeCount > 0 {
                Label(
                    "有 \(session.outOfRangeCount) 个音超出第一把位，暂不显示指法",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(PracticePalette.accent)
            }
        }
        .practiceSurface()
    }

    // MARK: - 播放控制

    private var transport: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Button(action: session.togglePlayback) {
                    Label(playLabel, systemImage: playIcon)
                }
                .buttonStyle(PressablePrimaryButtonStyle())
                .disabled(session.isPreparing)

                Button(action: session.stop) {
                    Image(systemName: "stop.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("停止")
            }

            ProgressView(
                value: min(session.currentTime, max(session.duration, 0.01)),
                total: max(session.duration, 0.01)
            )
            .tint(PracticePalette.accent)

            HStack {
                Text(transportHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach([0.5, 0.6, 0.7, 0.8, 0.9, 1.0], id: \.self) { rate in
                        Button(tempoLabel(rate)) {
                            session.setTempoScale(rate)
                        }
                    }
                } label: {
                    Label(tempoLabel(session.tempoScale), systemImage: "speedometer")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("播放速度")
            }

            HStack(spacing: 20) {
                Toggle(isOn: metronomeBinding) {
                    Text("节拍器")
                        .font(.subheadline)
                }
                .tint(PracticePalette.accent)

                Toggle(isOn: countInBinding) {
                    Text("预备拍")
                        .font(.subheadline)
                }
                .tint(PracticePalette.accent)
            }
            .toggleStyle(.switch)

            Text(session.countInEnabled
                 ? "开始前先听一小节拍点，再按谱跟奏"
                 : "节拍器只在播放时发声；预备拍会先给一小节拍点")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(
                isOn: Binding(
                    get: { session.loopEnabled },
                    set: { session.setLoopEnabled($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("片段循环").font(.subheadline.weight(.semibold))
                    Text("重复所选小节；改速度或循环方式会从头开始")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(PracticePalette.accent)

            if session.loopEnabled {
                VStack(spacing: 6) {
                    Stepper(
                        value: Binding(
                            get: { session.loopStartMeasure },
                            set: { session.setLoopStartMeasure($0) }
                        ),
                        in: 1...max(1, session.measureCount)
                    ) {
                        Text("从第 \(session.normalizedLoopRange.lowerBound) 小节")
                            .font(.subheadline)
                    }
                    Stepper(
                        value: Binding(
                            get: { session.loopEndMeasure },
                            set: { session.setLoopEndMeasure($0) }
                        ),
                        in: session.normalizedLoopRange.lowerBound...max(1, session.measureCount)
                    ) {
                        Text("到第 \(session.normalizedLoopRange.upperBound) 小节")
                            .font(.subheadline)
                    }
                }
                .padding(12)
                .background(PracticePalette.accent.opacity(0.06))
                .clipShape(.rect(cornerRadius: 6))

                Button("改为整首循环", action: session.resetLoopToWholeScore)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .practiceSurface()
    }

    private var transportHint: String {
        if session.isPreparing { return "正在准备音色…" }
        if session.isCountingIn { return "预备拍… 准备跟奏" }
        return "播放时会自动高亮当前音"
    }

    private var metronomeBinding: Binding<Bool> {
        Binding(
            get: { session.metronomeEnabled },
            set: { session.setMetronomeEnabled($0) }
        )
    }

    private var countInBinding: Binding<Bool> {
        Binding(
            get: { session.countInEnabled },
            set: { session.setCountInEnabled($0) }
        )
    }

    private var playLabel: String {
        if session.isPreparing { return "准备中" }
        return session.isPlaying ? "暂停" : "播放"
    }

    private var playIcon: String {
        if session.isPreparing { return "ellipsis" }
        return session.isPlaying ? "pause.fill" : "play.fill"
    }

    private func tempoLabel(_ rate: Double) -> String {
        rate.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }

    private func formatTime(_ value: Double) -> String {
        let seconds = max(0, Int(value.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct NoteCell: View {
    let note: ScoreNote
    let isCurrent: Bool

    private var fingering: ScoreFingering? {
        FirstPositionFingering.fingering(forMIDINote: note.midiNote)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(PitchName.name(for: note.midiNote))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isCurrent ? .white.opacity(0.85) : .secondary)
            Text(fingering?.fingerLabel ?? "—")
                .font(.title3.weight(.bold))
            Text(fingering?.string.rawValue ?? "超")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isCurrent ? .white.opacity(0.85) : .secondary)
        }
        .frame(width: 46, height: 72)
        .background(isCurrent ? PracticePalette.accent : PracticePalette.accent.opacity(0.08))
        .foregroundStyle(isCurrent ? .white : .primary)
        .clipShape(.rect(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let name = PitchName.name(for: note.midiNote)
        guard let fingering else { return "\(name)，超出第一把位" }
        return "\(name)，\(fingering.positionDescription)"
    }
}
