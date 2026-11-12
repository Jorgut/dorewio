import AVFoundation
import Combine
import Foundation

/// 「曲目」页的乐谱练习会话：导入 MusicXML、按谱试听、降速与片段循环。
@MainActor
final class ScorePracticeSession: ObservableObject {
    @Published private(set) var score: ImportedScore?
    @Published private(set) var fileName = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var isPreparing = false
    @Published private(set) var currentTime = 0.0
    @Published private(set) var currentNoteIndex: Int?
    @Published var tempoScale = 1.0
    @Published var loopEnabled = false
    @Published var loopStartMeasure = 1
    @Published var loopEndMeasure = 1
    @Published var metronomeEnabled = false
    @Published var countInEnabled = false
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var progressTimer: Timer?
    private var playbackGeneration = 0
    private var preparedTimeline: ScorePlaybackTimeline?

    init() {
        engine.attach(player)
    }

    // MARK: - 派生状态

    var measureCount: Int { score?.measureCount ?? 0 }

    var noteCount: Int { score?.notes.count ?? 0 }

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

    /// 正在播放且还没走完预备拍。
    var isCountingIn: Bool {
        guard isPlaying, let plan = preparedTimeline else { return false }
        return currentTime < plan.leadInSeconds
    }

    var normalizedLoopRange: ClosedRange<Int> {
        guard measureCount > 0 else { return 1...1 }
        let start = min(max(1, loopStartMeasure), measureCount)
        let end = min(max(start, loopEndMeasure), measureCount)
        return start...end
    }

    // MARK: - 导入

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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
        guard plan.totalSeconds <= 240 else {
            errorMessage = "这段约 \(Int(plan.totalSeconds / 60) + 1) 分钟，超过 4 分钟上限；请缩短循环小节"
            return
        }

        isPreparing = true
        playbackGeneration += 1
        let generation = playbackGeneration

        Task { [weak self] in
            guard let self else { return }
            let outputRate = self.engine.outputNode.outputFormat(forBus: 0).sampleRate
            let sampleRate = outputRate > 0 ? outputRate : 44_100
            let metronomeEnabled = self.metronomeEnabled
            let samples = await Task.detached(priority: .userInitiated) {
                ScorePlayback.renderSamples(
                    timeline: plan,
                    sampleRate: sampleRate,
                    metronomeEnabled: metronomeEnabled
                )
            }.value

            guard generation == self.playbackGeneration else { return }
            self.isPreparing = false
            guard self.isPlaying == false else { return }
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
        preparedTimeline = nil
        isPlaying = false
        isPreparing = false
        currentTime = 0
        currentNoteIndex = nil
    }

    // MARK: - 速度、循环与节拍

    func setTempoScale(_ value: Double) {
        let clamped = min(ScorePlayback.maximumTempoScale, max(ScorePlayback.minimumTempoScale, value))
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

    func setMetronomeEnabled(_ value: Bool) {
        guard value != metronomeEnabled else { return }
        rebuild { metronomeEnabled = value }
    }

    func setCountInEnabled(_ value: Bool) {
        guard value != countInEnabled else { return }
        rebuild { countInEnabled = value }
    }

    func setLoopStartMeasure(_ value: Int) {
        rebuild {
            loopStartMeasure = value
            if loopEndMeasure < value { loopEndMeasure = value }
        }
    }

    func setLoopEndMeasure(_ value: Int) {
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
        currentTime = 0
        currentNoteIndex = nil
        isPlaying = true
        startProgressTimer()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateProgress() }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let plan = preparedTimeline, plan.totalSeconds > 0 else { return }
        guard let lastRenderTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: lastRenderTime) else { return }

        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        let total = plan.totalSeconds
        let displayTime = loopEnabled ? elapsed.truncatingRemainder(dividingBy: total) : min(elapsed, total)

        currentTime = displayTime
        currentNoteIndex = plan.eventIndex(at: displayTime)

        if !loopEnabled, elapsed >= total {
            finishPlayback()
        }
    }

    private func finishPlayback() {
        let total = preparedTimeline?.totalSeconds ?? 0
        player.stop()
        if engine.isRunning { engine.stop() }
        stopProgressTimer()
        preparedTimeline = nil
        isPlaying = false
        currentTime = total
        currentNoteIndex = nil
    }
}
