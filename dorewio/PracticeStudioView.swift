import SwiftUI
import UniformTypeIdentifiers

struct PracticeStudioView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @StateObject private var session = PracticeStudioSession()
    @StateObject private var scoreSession = ScorePracticeSession()
    @State private var showsImporter = false
    @State private var showsScoreImporter = false
    @State private var practiceStartedAt: Date?

    private static let scoreTypes: [UTType] = {
        var types: [UTType] = []
        // .mxl（压缩 MusicXML）与 .musicxml 没有系统声明的类型，用扩展名生成动态类型，
        // 让文件选择器能够筛出这两种乐谱。
        for ext in ["mxl", "musicxml"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        types.append(.xml)
        return types
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PracticeSectionHeader(
                    eyebrow: "曲目工作室",
                    title: "把喜欢的旋律拆开练",
                    detail: "导入乐谱直接跟奏，或用音频放慢、循环再提取旋律"
                )

                ScoreWorkbench(session: scoreSession) { showsScoreImporter = true }

                if session.audioURL == nil {
                    StudioEmptyState(
                        isRecording: session.isRecording,
                        importAction: { showsImporter = true },
                        recordAction: { Task { await session.toggleRecording() } }
                    )
                } else {
                    AudioSourceBar(
                        name: session.audioName,
                        isRecording: session.isRecording,
                        importAction: { showsImporter = true },
                        recordAction: { Task { await session.toggleRecording() } }
                    )
                    PlayerWorkbench(session: session)
                    LoopWorkbench(session: session)
                    TranscriptionWorkbench(session: session)
                }
            }
            .padding()
        }
        .background(PracticePalette.canvas)
        .navigationTitle("工作室")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url): session.importAudio(from: url)
            case .failure(let error): session.errorMessage = "无法打开文件：\(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $showsScoreImporter, allowedContentTypes: Self.scoreTypes) { result in
            switch result {
            case .success(let url): scoreSession.importScore(from: url)
            case .failure(let error): scoreSession.errorMessage = "无法打开文件：\(error.localizedDescription)"
            }
        }
        .alert("提示", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .alert("乐谱提示", isPresented: Binding(
            get: { scoreSession.errorMessage != nil },
            set: { if !$0 { scoreSession.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { scoreSession.errorMessage = nil }
        } message: {
            Text(scoreSession.errorMessage ?? "")
        }
        .onChange(of: session.isPlaying) {
            if session.isPlaying { scoreSession.pause() }
            updatePracticeTimer(isActive: session.isPlaying || scoreSession.isPlaying)
        }
        .onChange(of: scoreSession.isPlaying) {
            if scoreSession.isPlaying { session.pause() }
            updatePracticeTimer(isActive: session.isPlaying || scoreSession.isPlaying)
        }
        .onDisappear {
            finishPractice()
            session.stop()
            scoreSession.stop()
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
        history.record(.repertoire, startedAt: startedAt, duration: Date.now.timeIntervalSince(startedAt))
        practiceStartedAt = nil
    }
}

private struct StudioEmptyState: View {
    let isRecording: Bool
    let importAction: () -> Void
    let recordAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: isRecording ? "waveform.badge.mic" : "waveform")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(PracticePalette.accent)
                    .frame(width: 64, height: 64)
                    .background(PracticePalette.accent.opacity(0.10))
                    .clipShape(.rect(cornerRadius: 7))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(isRecording ? "正在录下这次练习" : "从一段声音开始")
                        .font(.title3.weight(.bold))
                    Text(isRecording ? "结束录音后会自动进入工作台" : "支持“文件”中的常见音频格式，也可以直接录音")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actions }
                VStack(spacing: 12) { actions }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .practiceSurface(padding: 20)
    }

    @ViewBuilder
    private var actions: some View {
        Button("导入音频", systemImage: "folder", action: importAction)
            .buttonStyle(.bordered)
        Button(isRecording ? "停止录音" : "开始录音", systemImage: isRecording ? "stop.fill" : "record.circle", action: recordAction)
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : PracticePalette.accent)
    }
}

private struct AudioSourceBar: View {
    let name: String
    let isRecording: Bool
    let importAction: () -> Void
    let recordAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(PracticePalette.accent.opacity(0.12))
                Image(systemName: "waveform").foregroundStyle(PracticePalette.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.headline).lineLimit(1)
                Text("本地音频 · 仅在此设备处理").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button("更换音频", systemImage: "folder", action: importAction)
                Button(isRecording ? "停止录音" : "新建录音", systemImage: isRecording ? "stop.fill" : "record.circle", action: recordAction)
            } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
            }
            .accessibilityLabel("音频操作")
        }
        .practiceSurface(padding: 12)
    }
}

private struct PlayerWorkbench: View {
    @ObservedObject var session: PracticeStudioSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("听与定位").font(.headline)
                Spacer()
                Text("\(formatTime(session.currentTime)) / \(formatTime(session.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            WaveformTimeline(
                samples: session.waveformSamples,
                currentTime: session.currentTime,
                duration: session.duration,
                loopEnabled: session.loopEnabled,
                loopStart: session.loopStart,
                loopEnd: session.loopEnd,
                seek: session.seek
            )
            .frame(height: 116)

            HStack(spacing: 18) {
                Button { session.seek(to: session.currentTime - 5) } label: {
                    Image(systemName: "gobackward.5").frame(width: 44, height: 44)
                }
                .accessibilityLabel("后退五秒")

                Button(action: session.togglePlayback) {
                    Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 58, height: 58)
                        .foregroundStyle(.white)
                        .background(PracticePalette.accent)
                        .clipShape(.circle)
                }
                .accessibilityLabel(session.isPlaying ? "暂停" : "播放")

                Button { session.seek(to: session.currentTime + 5) } label: {
                    Image(systemName: "goforward.5").frame(width: 44, height: 44)
                }
                .accessibilityLabel("前进五秒")

                Spacer()

                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25], id: \.self) { rate in
                        Button(rateLabel(Float(rate))) {
                            session.playbackRate = Float(rate)
                            session.updateRate()
                        }
                    }
                } label: {
                    Label(rateLabel(session.playbackRate), systemImage: "speedometer")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .practiceSurface()
    }

    private func formatTime(_ value: Double) -> String {
        let seconds = max(0, Int(value.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func rateLabel(_ value: Float) -> String {
        value.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }
}

private struct WaveformTimeline: View {
    let samples: [Float]
    let currentTime: Double
    let duration: Double
    let loopEnabled: Bool
    let loopStart: Double
    let loopEnd: Double
    let seek: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                if loopEnabled, duration > 0 {
                    let startX = size.width * loopStart / duration
                    let endX = size.width * loopEnd / duration
                    context.fill(
                        Path(CGRect(x: startX, y: 0, width: max(1, endX - startX), height: size.height)),
                        with: .color(PracticePalette.accent.opacity(0.08))
                    )
                }

                let values = samples.isEmpty ? Array(repeating: Float(0.12), count: 48) : samples
                let barWidth = size.width / CGFloat(values.count)
                for (index, sample) in values.enumerated() {
                    let height = max(3, CGFloat(sample) * size.height * 0.82)
                    let x = CGFloat(index) * barWidth
                    let played = duration > 0 && x / size.width <= currentTime / duration
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: max(1, barWidth * 0.46), height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(played ? PracticePalette.accent : .secondary.opacity(0.34)))
                }

                if duration > 0 {
                    let x = size.width * currentTime / duration
                    var playhead = Path()
                    playhead.move(to: CGPoint(x: x, y: 0))
                    playhead.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(playhead, with: .color(PracticePalette.accent), lineWidth: 2)
                }
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard duration > 0 else { return }
                seek(max(0, min(duration, duration * value.location.x / proxy.size.width)))
            })
        }
        .accessibilityElement()
        .accessibilityLabel("音频波形")
        .accessibilityValue(duration > 0 ? "播放到百分之 \(Int(currentTime / duration * 100))" : "未加载")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: seek(currentTime + 5)
            case .decrement: seek(currentTime - 5)
            @unknown default: break
            }
        }
    }
}

private struct LoopWorkbench: View {
    @ObservedObject var session: PracticeStudioSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("A/B 循环").font(.headline)
                    Text("在播放位置设置起点和终点").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("A/B 循环", isOn: $session.loopEnabled).labelsHidden().tint(PracticePalette.accent)
            }

            HStack(spacing: 10) {
                Button("设为 A", systemImage: "a.circle", action: session.setLoopStart)
                Button("设为 B", systemImage: "b.circle", action: session.setLoopEnd)
                Spacer()
                Text("\(formatTime(session.loopStart)) – \(formatTime(session.loopEnd))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .practiceSurface()
    }

    private func formatTime(_ value: Double) -> String {
        let seconds = max(0, Int(value.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct TranscriptionWorkbench: View {
    @ObservedObject var session: PracticeStudioSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PracticeSectionHeader(
                eyebrow: "单旋律识谱",
                title: "单旋律扒谱",
                detail: "最适合小提琴独奏或干净的人声旋律"
            )

            LabeledContent("乐曲速度") {
                Stepper("\(Int(session.transcriptionBPM)) BPM", value: $session.transcriptionBPM, in: 40...200, step: 1)
                    .monospacedDigit()
            }

            Button(action: session.transcribe) {
                Label(session.isTranscribing ? "正在分析音高与时值" : "开始离线扒谱", systemImage: "music.note.list")
            }
            .buttonStyle(PressablePrimaryButtonStyle())
            .disabled(session.isTranscribing)

            if session.isTranscribing {
                ProgressView("分析过程中可以留在此页")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let score = session.score {
                ScorePreview(score: score)
                HStack {
                    Label("\(score.notes.count) 个音符", systemImage: "checkmark.circle.fill")
                        .font(.callout).foregroundStyle(PracticePalette.success)
                    Spacer()
                    if let exportURL = session.exportURL {
                        ShareLink(item: exportURL) {
                            Label("MusicXML", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ScorePreview: View {
    let score: MelodyScore

    var body: some View {
        ScrollView(.horizontal) {
            Canvas { context, size in
                let top = 28.0
                let spacing = 12.0
                for line in 0..<5 {
                    let y = top + Double(line) * spacing
                    var staff = Path()
                    staff.move(to: CGPoint(x: 0, y: y))
                    staff.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(staff, with: .color(.secondary.opacity(0.38)), lineWidth: 1)
                }

                for (index, note) in score.notes.enumerated() {
                    let x = 34 + Double(index) * 40
                    let y = max(8, min(92, 76 - Double(note.midiNote - 60) * 3))
                    let rect = CGRect(x: x, y: y, width: 15, height: 9)
                    context.fill(Path(ellipseIn: rect), with: .color(.primary))
                    var stem = Path()
                    stem.move(to: CGPoint(x: rect.maxX, y: rect.midY))
                    stem.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - 29))
                    context.stroke(stem, with: .color(.primary), lineWidth: 1.5)

                    let label = Text(noteName(note.midiNote)).font(.caption2).foregroundStyle(.secondary)
                    context.draw(label, at: CGPoint(x: rect.midX, y: 108), anchor: .center)
                }
            }
            .frame(width: max(340, CGFloat(score.notes.count) * 40 + 70), height: 122)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("旋律预览，共 \(score.notes.count) 个音符")
    }

    private func noteName(_ midi: Int) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        return names[(midi % 12 + 12) % 12]
    }
}
