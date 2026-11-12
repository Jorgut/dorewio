import AVFoundation
import Foundation

enum AudioTranscriptionService {
    nonisolated static func transcribe(url: URL, bpm: Double) async throws -> MelodyScore {
        try await Task.detached(priority: .userInitiated) {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameSize: AVAudioFrameCount = 2_048
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameSize) else {
                throw TranscriptionError.unreadableAudio
            }

            var frames: [PitchFrame] = []
            var sampleOffset: AVAudioFramePosition = 0
            while file.framePosition < file.length {
                try file.read(into: buffer, frameCount: frameSize)
                guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }

                let count = Int(buffer.frameLength)
                var mono = Array(repeating: Float.zero, count: count)
                for channelIndex in 0..<Int(format.channelCount) {
                    for index in 0..<count {
                        mono[index] += channels[channelIndex][index] / Float(format.channelCount)
                    }
                }

                let frequency = PitchDetector.estimateFrequency(
                    samples: mono,
                    sampleRate: format.sampleRate,
                    minimumFrequency: 150,
                    maximumFrequency: 1_200
                )
                frames.append(PitchFrame(
                    time: Double(sampleOffset) / format.sampleRate,
                    frequency: frequency
                ))
                sampleOffset += AVAudioFramePosition(buffer.frameLength)
            }

            let frameDuration = Double(frameSize) / format.sampleRate
            let notes = MonophonicTranscriber.transcribe(
                frames: frames,
                frameDuration: frameDuration,
                minimumNoteDuration: max(0.10, frameDuration * 2)
            )
            guard !notes.isEmpty else { throw TranscriptionError.noMelodyFound }
            return MelodyScore(
                notes: notes,
                bpm: bpm,
                title: url.deletingPathExtension().lastPathComponent
            )
        }.value
    }
}

enum TranscriptionError: LocalizedError {
    case unreadableAudio
    case noMelodyFound

    var errorDescription: String? {
        switch self {
        case .unreadableAudio: "无法读取这个音频文件"
        case .noMelodyFound: "没有识别到清晰的单旋律，请尝试小提琴独奏或更干净的录音"
        }
    }
}
