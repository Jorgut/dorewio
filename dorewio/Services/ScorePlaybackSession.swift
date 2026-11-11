import AVFoundation
import Combine
import Foundation

/// dorewio 乐谱页的播放会话：导入 MusicXML / MXL，按谱发声、降速与片段循环。
///
/// 琴声与节拍器会在内存里预渲染成一条单声道缓冲，因此改速度、节拍器或循环设置
/// 都需要重建缓冲；若正在播放，重建后会从片段开头继续。
@MainActor
final class ScorePlaybackSession: ObservableObject {
    /// 界面提供的播放速度档位（相对乐谱标记速度）。
    static let tempoChoices: [Double] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    /// 单次播放时长上限：超过后提示用片段循环缩短范围。
    static let maximumPlaybackSeconds: Double = 240
    /// 界面允许的播放速度范围；0.5× 足够慢，1.0× 即乐谱原速。
    static let minimumTempoScale: Double = 0.5
    static let maximumTempoScale: Double = 1.0

    // MARK: - 乐谱与播放状态

    @Published private(set) var score: ImportedScore?
    @Published private(set) var fileName = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var isPreparing = false
    @Published private(set) var currentTime = 0.0
    @Published private(set) var currentNoteIndex: Int?

    // MARK: - 练习设置

    @Published private(set) var tempoScale = 1.0
    @Published private(set) var loopEnabled = false
    @Published private(set) var loopStartMeasure = 1
    @Published private(set) var loopEndMeasure = 1
    @Published private(set) var metronomeEnabled = false
    @Published private(set) var countInEnabled = false

    /// 导入失败或播放出错时的中文提示，由界面用 alert 展示。
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var progressTimer: Timer?
    private var playbackGeneration = 0
    private var preparedTimeline: ScorePlaybackTimeline?
    /// 预渲染缓冲的实际时长（含收尾采样），用于对齐循环进度。
    private var renderedBufferSeconds = 0.0

    init() {
        engine.attach(player)
    }

    // MARK: - 派生状态

    var measureCount: Int { score?.measureCount ?? 0 }

    var noteCount: Int { score?.notes.count ?? 0 }

    /// 超出第一把位、无法给出指法的音符数量。
    var outOfRangeCount: Int {
        score?.notes.reduce(0) { count, note in
            FirstPositionFingering.isPlayable(midiNote: note.midiNote) ? count : count + 1
        } ?? 0
    }

    var bpm: Double { score?.bpm ?? 0 }

    /// 当前速度与循环设置下的完整时间轴，用于显示总时长。
    var timeline: ScorePlaybackTimeline {
        guard let score else {
            return ScorePlaybackTimeline(events: [], totalSeconds: 0, tempoScale: tempoScale)
        }
        return ScorePlayback.timeline(
            score: score,
            tempoScale: tempoScale,
            loopMeasures: loopEnabled ? normalizedLoopRange : nil,
            countInMeasures: countInEnabled ? 1 : 0
        )
    }

    var duration: Double { timeline.totalSeconds }

    /// 正在播放且还没走完预备拍；这期间不高亮音符。
    var isCountingIn: Bool {
        guard isPlaying, let plan = preparedTimeline else { return false }
        return currentTime < plan.leadInSeconds
    }

    /// 把循环小节限制在乐谱范围内，并保证起点不大于终点。
    var normalizedLoopRange: ClosedRange<Int> {
        guard measureCount > 0 else { return 1...1 }
        let start = min(max(1, loopStartMeasure), measureCount)
        let end = min(max(start, loopEndMeasure), measureCount)
        return start...end
    }

    // MARK: - 导入与移除

    func importScore(from url: URL) {
        stop()
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let imported = try MusicXMLParser.parse(contentsOf: url)
            score = imported
            fileName = url.lastPathComponent
            tempoScale = 1
            loopEnabled = false
            loopStartMeasure = 1
            loopEndMeasure = imported.measureCount
            currentTime = 0
            currentNoteIndex = nil
            errorMessage = nil
        } catch {
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                errorMessage = description
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeScore() {
        stop()
        score = nil
        fileName = ""
        loopStartMeasure = 1
        loopEndMeasure = 1
        currentTime = 0
        currentNoteIndex = nil
    }

    // MARK: - 播放控制

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let score, !isPlaying, !isPreparing else { return }

        // 暂停后继续：缓冲还在，直接让播放器接着走。
        if preparedTimeline != nil {
            player.play()
            isPlaying = true
            startProgressTimer()
            return
        }

        let plan = ScorePlayback.timeline(
            score: score,
            tempoScale: tempoScale,
            loopMeasures: loopEnabled ? normalizedLoopRange : nil,
            countInMeasures: countInEnabled ? 1 : 0
        )
        guard !plan.events.isEmpty else {
            errorMessage = "所选小节里没有可播放的音符"
            return
        }
        guard plan.totalSeconds <= Self.maximumPlaybackSeconds else {
            let minutes = Int((plan.totalSeconds / 60).rounded(.up))
            errorMessage = "整段约 \(minutes) 分钟，超过 4 分钟上限；请打开片段循环缩短播放范围"
            return
        }

        isPreparing = true
        playbackGeneration += 1
        let generation = playbackGeneration
        let metronomeEnabled = self.metronomeEnabled

        Task { [weak self] in
            guard let self else { return }
            let outputRate = self.engine.outputNode.outputFormat(forBus: 0).sampleRate
            let sampleRate = outputRate > 0 ? outputRate : 44_100
            let samples = await Task.detached(priority: .userInitiated) {
                ScorePlayback.renderSamples(
                    timeline: plan,
                    sampleRate: sampleRate,
                    metronomeEnabled: metronomeEnabled
                )
            }.value

            guard generation == self.playbackGeneration else { return }
            self.isPreparing = false
            self.startPlayback(samples: samples, plan: plan, sampleRate: sampleRate)
        }
    }

    func pause() {
        guard isPlaying else { return }
        player.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func stop() {
        playbackGeneration += 1
        player.stop()
        if engine.isRunning { engine.stop() }
        engine.reset()
        stopProgressTimer()
        deactivateAudioSession()
        preparedTimeline = nil
        renderedBufferSeconds = 0
        isPlaying = false
        isPreparing = false
        currentTime = 0
        currentNoteIndex = nil
    }

    // MARK: - 速度、循环与节拍

    func setTempoScale(_ value: Double) {
        let clamped = min(Self.maximumTempoScale, max(Self.minimumTempoScale, value))
        guard abs(clamped - tempoScale) > 0.000_1 else { return }
        rebuild { tempoScale = clamped }
    }

    func setLoopEnabled(_ value: Bool) {
        guard value != loopEnabled else { return }
        rebuild {
            loopEnabled = value
            loopStartMeasure = normalizedLoopRange.lowerBound
            loopEndMeasure = normalizedLoopRange.upperBound
        }
    }

    func setLoopStartMeasure(_ value: Int) {
        guard value != loopStartMeasure else { return }
        rebuild {
            loopStartMeasure = value
            if loopEndMeasure < value { loopEndMeasure = value }
        }
    }

    func setLoopEndMeasure(_ value: Int) {
        guard value != loopEndMeasure else { return }
        rebuild {
            loopEndMeasure = value
            if loopStartMeasure > value { loopStartMeasure = value }
        }
    }

    func resetLoopToWholeScore() {
        rebuild {
            loopStartMeasure = 1
            loopEndMeasure = measureCount
        }
    }

    func setMetronomeEnabled(_ value: Bool) {
        guard value != metronomeEnabled else { return }
        rebuild { metronomeEnabled = value }
    }

    func setCountInEnabled(_ value: Bool) {
        guard value != countInEnabled else { return }
        rebuild { countInEnabled = value }
    }

    /// 改速度或循环会重建音色缓冲；正在播放时从头继续。
    private func rebuild(_ change: () -> Void) {
        let wasPlaying = isPlaying
        stop()
        change()
        if wasPlaying { play() }
    }

    // MARK: - 播放实现

    private func startPlayback(samples: [Float], plan: ScorePlaybackTimeline, sampleRate: Double) {
        guard !samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(samples.count)
              ) else {
            errorMessage = "无法准备这段乐谱的音频"
            return
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData?[0] {
            for (index, sample) in samples.enumerated() {
                channel[index] = sample
            }
        }

        player.stop()
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: loopEnabled ? [.loops] : [])
            player.play()
        } catch {
            errorMessage = "无法开始播放：\(error.localizedDescription)"
            stop()
            return
        }

        preparedTimeline = plan
        renderedBufferSeconds = Double(samples.count) / sampleRate
        currentTime = 0
        currentNoteIndex = nil
        isPlaying = true
        startProgressTimer()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
        // 用 common 模式：滚动音符条时进度也会继续更新。
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// 停止试听后释放音频会话，让其他 App 的音乐可以继续播放。
    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func updateProgress() {
        guard let plan = preparedTimeline, plan.totalSeconds > 0 else { return }
        guard let lastRenderTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: lastRenderTime),
              playerTime.sampleRate > 0 else { return }

        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        let total = plan.totalSeconds

        if loopEnabled {
            // 循环时按整条缓冲的周期取余，避免收尾采样让高亮逐圈漂移。
            let period = renderedBufferSeconds > 0 ? renderedBufferSeconds : total
            currentTime = min(elapsed.truncatingRemainder(dividingBy: period), total)
        } else {
            currentTime = min(elapsed, total)
        }
        currentNoteIndex = plan.eventIndex(at: currentTime)

        if !loopEnabled, elapsed >= total {
            finishPlayback()
        }
    }

    private func finishPlayback() {
        let total = preparedTimeline?.totalSeconds ?? 0
        player.stop()
        if engine.isRunning { engine.stop() }
        engine.reset()
        stopProgressTimer()
        deactivateAudioSession()
        preparedTimeline = nil
        renderedBufferSeconds = 0
        isPlaying = false
        currentTime = total
        currentNoteIndex = nil
    }
}
