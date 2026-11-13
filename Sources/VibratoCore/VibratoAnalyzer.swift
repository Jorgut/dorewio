import Foundation

public struct PitchSample: Equatable, Sendable {
    public let time: TimeInterval
    public let centsFromTarget: Double

    public init(time: TimeInterval, centsFromTarget: Double) {
        self.time = time
        self.centsFromTarget = centsFromTarget
    }
}

public enum VibratoFeedback: String, Equatable, Sendable {
    case good
    case tooNarrow
    case tooWide
    case tooSlow
    case tooFast
    case irregular
    case centerFlat
    case centerSharp
}

public struct VibratoResult: Equatable, Sendable {
    public let rateHz: Double
    public let extentCents: Double
    public let regularity: Double
    public let centerOffsetCents: Double
    public let feedback: VibratoFeedback
}

public struct VibratoAnalyzer: Sendable {
    public init() {}

    public func analyze(samples: [PitchSample]) -> VibratoResult? {
        guard samples.count >= 20,
              let first = samples.first,
              let last = samples.last,
              last.time - first.time >= 0.5 else {
            return nil
        }

        let center = samples.map(\.centsFromTarget).reduce(0, +) / Double(samples.count)
        let centered = samples.map { $0.centsFromTarget - center }
        let sorted = samples.map(\.centsFromTarget).sorted()
        let lower = percentile(sorted, fraction: 0.05)
        let upper = percentile(sorted, fraction: 0.95)
        let extent = upper - lower
        let crossings = upwardCrossingTimes(samples: samples, centeredValues: centered)

        guard crossings.count >= 3 else { return nil }

        let intervals = zip(crossings.dropFirst(), crossings).map(-)
        let meanInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard meanInterval > 0 else { return nil }

        let variance = intervals
            .map { pow($0 - meanInterval, 2) }
            .reduce(0, +) / Double(intervals.count)
        let coefficientOfVariation = sqrt(variance) / meanInterval
        let regularity = max(0, min(1, 1 - coefficientOfVariation * 3))
        let rate = 1 / meanInterval
        let feedback = feedback(
            center: center,
            extent: extent,
            rate: rate,
            regularity: regularity
        )

        return VibratoResult(
            rateHz: rate,
            extentCents: extent,
            regularity: regularity,
            centerOffsetCents: center,
            feedback: feedback
        )
    }

    private func percentile(_ sortedValues: [Double], fraction: Double) -> Double {
        let position = fraction * Double(sortedValues.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = Int(position.rounded(.up))
        guard lowerIndex != upperIndex else { return sortedValues[lowerIndex] }

        let weight = position - Double(lowerIndex)
        return sortedValues[lowerIndex] * (1 - weight) + sortedValues[upperIndex] * weight
    }

    private func upwardCrossingTimes(
        samples: [PitchSample],
        centeredValues: [Double]
    ) -> [TimeInterval] {
        guard samples.count == centeredValues.count else { return [] }

        var times: [TimeInterval] = []
        for index in 1..<samples.count {
            let previous = centeredValues[index - 1]
            let current = centeredValues[index]
            guard previous <= 0, current > 0 else { continue }

            let span = current - previous
            let fraction = span == 0 ? 0 : -previous / span
            let start = samples[index - 1].time
            let duration = samples[index].time - start
            times.append(start + duration * fraction)
        }
        return times
    }

    private func feedback(
        center: Double,
        extent: Double,
        rate: Double,
        regularity: Double
    ) -> VibratoFeedback {
        if center > 12 { return .centerSharp }
        if center < -12 { return .centerFlat }
        if extent < 20 { return .tooNarrow }
        if extent > 100 { return .tooWide }
        if rate < 4 { return .tooSlow }
        if rate > 8 { return .tooFast }
        if regularity < 0.65 { return .irregular }
        return .good
    }
}
