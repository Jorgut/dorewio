import AVFoundation
import Foundation

enum AudioWaveformService {
    nonisolated static func samples(for url: URL, count targetCount: Int = 120) async -> [Float] {
        await Task.detached(priority: .utility) {
            guard targetCount > 0, let file = try? AVAudioFile(forReading: url) else { return [] }
            let format = file.processingFormat
            let framesPerBucket = max(512, Int(file.length) / targetCount)
            let capacity = AVAudioFrameCount(min(framesPerBucket, 16_384))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return [] }

            var raw: [Float] = []
            while file.framePosition < file.length {
                guard (try? file.read(into: buffer, frameCount: capacity)) != nil,
                      buffer.frameLength > 0,
                      let channels = buffer.floatChannelData else { break }

                let frameCount = Int(buffer.frameLength)
                var sum: Float = 0
                for channel in 0..<Int(format.channelCount) {
                    for frame in 0..<frameCount {
                        let value = channels[channel][frame]
                        sum += value * value
                    }
                }
                let divisor = Float(max(1, frameCount * Int(format.channelCount)))
                raw.append(sqrt(sum / divisor))
            }

            guard let peak = raw.max(), peak > 0 else { return [] }
            if raw.count <= targetCount { return raw.map { $0 / peak } }

            return (0..<targetCount).map { index in
                let start = index * raw.count / targetCount
                let end = max(start + 1, (index + 1) * raw.count / targetCount)
                return (raw[start..<end].max() ?? 0) / peak
            }
        }.value
    }
}
