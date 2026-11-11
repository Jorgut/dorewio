import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 「乐谱」页：导入单声部 MusicXML / MXL，按谱发声并显示第一把位的弦与指法。
///
/// 与「练习」页共用 dorewio 的品牌语言：白底、暖灰卡片、砖红色强调，
/// 不依赖麦克风——导入后直接听谱、降速或循环跟奏。
struct ScorePracticeView: View {
    @StateObject private var session = ScorePlaybackSession()
    @State private var showsImporter = false

    private static let scoreTypes: [UTType] = {
        var types: [UTType] = []
        // .mxl 与 .musicxml 没有系统声明的类型，用扩展名生成动态类型，
        // 让文件选择器能筛选出这两种乐谱。
        for ext in ["mxl", "musicxml"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        types.append(.xml)
        return types
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let score = session.score {
                    scoreInfoCard(score)
                    noteStripCard(score)
                    transportCard
                    settingsCard
                } else {
                    emptyCard
                }
            }
            .padding(20)
        }
        .background(ScorePalette.canvas)
        .tint(ScorePalette.accent)
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: Self.scoreTypes
        ) { result in
            switch result {
            case .success(let url):
                session.importScore(from: url)
            case .failure(let error):
                session.errorMessage = "无法打开文件：\(error.localizedDescription)"
            }
        }
        .alert("乐谱提示", isPresented: isShowingError) {
            Button("好", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .onDisappear {
            // 切到「练习」页时停止试听，避免隐藏的标签页继续出声。
            session.stop()
        }
    }

    // MARK: - 顶部品牌区

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("dorewio.")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("SCORE · PLAY ALONG")
                    .font(.caption.weight(.medium))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ScorePalette.accent)
                .frame(width: 52, height: 52)
                .background(ScorePalette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
        }
    }

    // MARK: - 空状态

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(ScorePalette.accent)
                    .frame(width: 56, height: 56)
                    .background(ScorePalette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("导入乐谱，直接演奏")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("按谱发声，并显示第一把位的弦与指号；不需要麦克风。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            Text("支持 .mxl（自动解压）、.musicxml 与 .xml 单声部乐谱。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showsImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                    Text("导入乐谱")
                    Spacer()
                    Image(systemName: "arrow.up.doc")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(ScorePalette.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("导入乐谱")
            .accessibilityHint("打开文件选择器，导入 MXL、MusicXML 或 XML 乐谱")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScorePalette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 乐谱信息

    private func scoreInfoCard(_ score: ImportedScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("当前乐谱")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(ScorePalette.accent)
                    Text(score.title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(score.measureCount) 小节 · \(score.notes.count) 个音 · \(Int(score.bpm.rounded())) BPM")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button {
                        showsImporter = true
                    } label: {
                        Label("更换乐谱", systemImage: "folder")
                    }
                    Button(role: .destructive) {
                        session.removeScore()
                    } label: {
                        Label("移除乐谱", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.white, in: Circle())
                }
                .accessibilityLabel("乐谱操作")
            }

            HStack(spacing: 7) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(session.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if session.outOfRangeCount > 0 {
                Label(
                    "其中 \(session.outOfRangeCount) 个音超出第一把位，暂不显示指法",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(ScorePalette.accent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScorePalette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 横向音符条

    private func noteStripCard(_ score: ImportedScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("音符与指法")
                    .font(.headline)
                Spacer()
                Text("共 \(score.notes.count) 个音")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(score.notes.indices, id: \.self) { index in
                            ScoreNoteCell(
                                note: score.notes[index],
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

            Text("指法：0 空弦 · 低1/1 · 低2/2 · 3 · 高3 · 4，均为第一把位；指号是左手位置，不是音高。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScorePalette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 播放控制

    private var transportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    session.togglePlayback()
                } label: {
                    Label(playButtonTitle, systemImage: playButtonIcon)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(ScorePalette.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(session.isPreparing)
                .accessibilityHint(transportHint)

                Button {
                    session.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ScorePalette.accent)
                        .frame(width: 54, height: 52)
                        .background(ScorePalette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("停止播放")
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progressValue, total: progressTotal)
                    .tint(ScorePalette.accent)
                    .accessibilityLabel("播放进度")
                    .accessibilityValue("\(formatTime(session.currentTime))，共 \(formatTime(session.duration))")
                HStack {
                    Text(formatTime(session.currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTime(session.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(transportHint)
                    .font(.caption)
                    .foregroundStyle(isPracticingHintVisible ? ScorePalette.accent : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                speedMenu
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScorePalette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var speedMenu: some View {
        Menu {
            ForEach(ScorePlaybackSession.tempoChoices, id: \.self) { rate in
                Button(tempoLabel(rate)) {
                    session.setTempoScale(rate)
                }
            }
        } label: {
            Label(tempoLabel(session.tempoScale), systemImage: "speedometer")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ScorePalette.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(ScorePalette.accent.opacity(0.10), in: Capsule())
        }
        .accessibilityLabel("播放速度，当前 \(tempoLabel(session.tempoScale))")
    }

    // MARK: - 循环、节拍器与预备拍

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("练习设置")
                .font(.headline)

            Toggle(isOn: loopEnabledBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("片段循环")
                        .font(.subheadline.weight(.semibold))
                    Text("只重复所选小节；改设置会从片段开头重新播放")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(ScorePalette.accent)

            if session.loopEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Stepper(value: loopStartBinding, in: 1...max(1, session.measureCount)) {
                        Text("从第 \(session.normalizedLoopRange.lowerBound) 小节开始")
                            .font(.subheadline)
                    }
                    Stepper(value: loopEndBinding, in: session.normalizedLoopRange.lowerBound...max(1, session.measureCount)) {
                        Text("到第 \(session.normalizedLoopRange.upperBound) 小节结束")
                            .font(.subheadline)
                    }
                    HStack {
                        Text("循环第 \(session.normalizedLoopRange.lowerBound)–\(session.normalizedLoopRange.upperBound) 小节（共 \(session.measureCount) 小节）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("整首循环") {
                            session.resetLoopToWholeScore()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ScorePalette.accent)
                        .accessibilityHint("把循环范围恢复为整首乐谱")
                    }
                }
                .padding(12)
                .background(ScorePalette.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }

            Divider()

            HStack(spacing: 18) {
                Toggle(isOn: metronomeBinding) {
                    Label("节拍器", systemImage: "metronome")
                        .font(.subheadline)
                }
                .tint(ScorePalette.accent)

                Toggle(isOn: countInBinding) {
                    Label("预备拍", systemImage: "timer")
                        .font(.subheadline)
                }
                .tint(ScorePalette.accent)
            }

            Text(beatHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScorePalette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 绑定与文案

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )
    }

    private var loopEnabledBinding: Binding<Bool> {
        Binding(
            get: { session.loopEnabled },
            set: { session.setLoopEnabled($0) }
        )
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

    private var loopStartBinding: Binding<Int> {
        Binding(
            get: { session.normalizedLoopRange.lowerBound },
            set: { session.setLoopStartMeasure($0) }
        )
    }

    private var loopEndBinding: Binding<Int> {
        Binding(
            get: { session.normalizedLoopRange.upperBound },
            set: { session.setLoopEndMeasure($0) }
        )
    }

    private var playButtonTitle: String {
        if session.isPreparing { return "准备中…" }
        return session.isPlaying ? "暂停" : "播放"
    }

    private var playButtonIcon: String {
        if session.isPreparing { return "ellipsis" }
        return session.isPlaying ? "pause.fill" : "play.fill"
    }

    private var transportHint: String {
        if session.isPreparing { return "正在准备音色…" }
        if session.isCountingIn { return "预备拍… 准备跟奏" }
        if session.isPlaying { return "播放中，当前音会自动高亮" }
        if session.currentTime > 0 { return "已暂停，继续播放会从暂停处接续" }
        return "播放时会自动高亮当前音"
    }

    private var isPracticingHintVisible: Bool {
        session.isPreparing || session.isCountingIn
    }

    private var beatHint: String {
        if session.countInEnabled && session.loopEnabled {
            return "预备拍会先给一小节拍点；循环时每一圈都会重新数预备拍。"
        }
        if session.countInEnabled {
            return "预备拍会先给一小节拍点，再进入乐谱；即使关闭节拍器，预备拍仍会发声。"
        }
        return "节拍器随乐谱播放；打开预备拍可先听一小节拍点再进曲。"
    }

    private var progressValue: Double {
        min(max(session.currentTime, 0), progressTotal)
    }

    private var progressTotal: Double {
        max(session.duration, 0.01)
    }

    private func tempoLabel(_ rate: Double) -> String {
        String(format: "%.1f×", rate)
    }

    private func formatTime(_ value: Double) -> String {
        let seconds = max(0, Int(value.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - 单个音符

/// 音符条里的一格：音名、指号、弦，当前音额外用描边与放大区分（不只靠颜色）。
private struct ScoreNoteCell: View {
    let note: ScoreNote
    let isCurrent: Bool

    private var fingering: ScoreFingering? {
        FirstPositionFingering.fingering(forMIDINote: note.midiNote)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(PitchName.name(for: note.midiNote))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isCurrent ? Color.white.opacity(0.9) : Color.secondary)
            Text(fingering?.fingerLabel ?? "超")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(isCurrent ? Color.white : Color.primary)
            Text(fingering?.string.rawValue ?? "—")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isCurrent ? Color.white.opacity(0.9) : Color.secondary)
        }
        .frame(width: 48, height: 74)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? ScorePalette.accent : ScorePalette.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isCurrent ? Color.white.opacity(0.85) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isCurrent ? 1.04 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let name = PitchName.name(for: note.midiNote)
        guard let fingering else { return "\(name)，超出第一把位，暂不显示指法" }
        let state = isCurrent ? "，当前音" : ""
        return "\(name)，\(fingering.positionDescription)\(state)"
    }
}

// MARK: - dorewio 乐谱页配色

private enum ScorePalette {
    static let accent = Color(red: 0.74, green: 0.24, blue: 0.20)
    static let canvas = Color.white
    static let surface = Color(white: 0.96)
}

#Preview {
    ScorePracticeView()
}
