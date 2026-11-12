import AVFoundation
import Combine
import Foundation

@MainActor
final class PracticeStudioSession: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var audioURL: URL?
    @Published private(set) var audioName = "尚未选择音频"
    @Published private(set) var duration = 0.0
    @Published var currentTime = 0.0
    @Published var playbackRate: Float = 1
    @Published var loopEnabled = false
    @Published var loopStart = 0.0
    @Published var loopEnd = 0.0
    @Published var transcriptionBPM = 80.0
    @Published private(set) var isPlaying = false
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var score: MelodyScore?
    @Published private(set) var exportURL: URL?
    @Published private(set) var waveformSamples: [Float] = []
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var progressTimer: Timer?

    func importAudio(from sourceURL: URL) {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            let directory = try Self.audioDirectory()
            let destination = directory.appendingPathComponent(UUID().uuidString + "-" + sourceURL.lastPathComponent)
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            try loadAudio(at: destination)
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard let player else { return }
        if currentTime >= duration { seek(to: loopEnabled ? loopStart : 0) }
        player.enableRate = true
        player.rate = playbackRate
        player.play()
        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func seek(to time: Double) {
        let clamped = max(0, min(duration, time))
        currentTime = clamped
        player?.currentTime = clamped
    }

    func updateRate() {
        player?.rate = playbackRate
    }

    func setLoopStart() {
        loopStart = min(currentTime, max(0, loopEnd - 0.1))
    }

    func setLoopEnd() {
        loopEnd = max(currentTime, min(duration, loopStart + 0.1))
    }

    func toggleRecording() async {
        if isRecording {
            stopRecording()
            return
        }
        guard await requestPermission() else {
            errorMessage = "请在系统设置中允许麦克风访问"
            return
        }
        startRecording()
    }

    func transcribe() {
        guard let audioURL, !isTranscribing else { return }
        pause()
        isTranscribing = true
        score = nil
        exportURL = nil
        errorMessage = nil
        let bpm = transcriptionBPM
        Task {
            do {
                let newScore = try await AudioTranscriptionService.transcribe(url: audioURL, bpm: bpm)
                score = newScore
                exportURL = writeMusicXML(newScore)
            } catch {
                errorMessage = error.localizedDescription
            }
            isTranscribing = false
        }
    }

    private func writeMusicXML(_ score: MelodyScore) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeFilename(score.title)).musicxml")
        do {
            try score.musicXML.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            errorMessage = "无法生成乐谱文件"
            return nil
        }
    }

    func stop() {
        pause()
        if isRecording { stopRecording() }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = duration
            stopProgressTimer()
        }
    }

    private func loadAudio(at url: URL) throws {
        stop()
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.delegate = self
        newPlayer.enableRate = true
        newPlayer.prepareToPlay()
        player = newPlayer
        audioURL = url
        audioName = url.deletingPathExtension().lastPathComponent
        duration = newPlayer.duration
        currentTime = 0
        loopStart = 0
        loopEnd = newPlayer.duration
        score = nil
        exportURL = nil
        waveformSamples = []
        Task {
            waveformSamples = await AudioWaveformService.samples(for: url)
        }
    }

    private func startRecording() {
        do {
            pause()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            let url = try Self.audioDirectory().appendingPathComponent("录音-\(Int(Date().timeIntervalSince1970)).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.record()
            recorder = newRecorder
            isRecording = true
        } catch {
            errorMessage = "无法开始录音：\(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        guard let recorder else { return }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        do {
            try loadAudio(at: recorder.url)
        } catch {
            errorMessage = "录音已保存，但无法加载：\(error.localizedDescription)"
        }
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
        guard let player else { return }
        currentTime = player.currentTime
        if loopEnabled, loopEnd > loopStart, currentTime >= loopEnd {
            player.currentTime = loopStart
            currentTime = loopStart
            if !player.isPlaying { player.play() }
        }
        if !player.isPlaying, currentTime < duration {
            isPlaying = false
            stopProgressTimer()
        }
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func audioDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("PracticeAudio", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func safeFilename(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}
