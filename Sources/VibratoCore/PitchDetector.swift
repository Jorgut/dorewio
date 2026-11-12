import Foundation

public enum PitchDetector {
    public nonisolated static func estimateFrequency(
        samples: [Float],
        sampleRate: Double,
        minimumFrequency: Double = 150,
        maximumFrequency: Double = 1_200
    ) -> Double? {
        guard samples.count >= 512, sampleRate > 0 else { return nil }

        let rms = sqrt(samples.reduce(0) { $0 + Double($1 * $1) } / Double(samples.count))
        guard rms > 0.01 else { return nil }

        let minimumLag = max(2, Int(sampleRate / maximumFrequency))
        let maximumLag = min(samples.count / 2, Int(sampleRate / minimumFrequency))
        guard minimumLag < maximumLag else { return nil }

        var difference = Array(repeating: 0.0, count: maximumLag + 1)
        for lag in 1...maximumLag {
            var sum = 0.0
            for index in 0..<(samples.count - lag) {
                let delta = Double(samples[index] - samples[index + lag])
                sum += delta * delta
            }
            difference[lag] = sum
        }

        var cumulative = 0.0
        var normalized = Array(repeating: 1.0, count: maximumLag + 1)
        for lag in 1...maximumLag {
            cumulative += difference[lag]
            normalized[lag] = cumulative == 0
                ? 1
                : difference[lag] * Double(lag) / cumulative
        }

        var candidate: Int?
        var lag = minimumLag
        while lag <= maximumLag {
            if normalized[lag] < 0.15 {
                while lag < maximumLag, normalized[lag + 1] < normalized[lag] {
                    lag += 1
                }
                candidate = lag
                break
            }
            lag += 1
        }

        if candidate == nil {
            candidate = (minimumLag...maximumLag).min { normalized[$0] < normalized[$1] }
        }

        guard let bestLag = candidate, normalized[bestLag] < 0.3 else { return nil }
        let refinedLag = parabolicLag(values: normalized, index: bestLag)
        return sampleRate / refinedLag
    }

    private nonisolated static func parabolicLag(values: [Double], index: Int) -> Double {
        guard index > 0, index < values.count - 1 else { return Double(index) }

        let left = values[index - 1]
        let center = values[index]
        let right = values[index + 1]
        let denominator = left - 2 * center + right
        guard abs(denominator) > .ulpOfOne else { return Double(index) }
        return Double(index) + 0.5 * (left - right) / denominator
    }
}
