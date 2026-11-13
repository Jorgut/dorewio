import Foundation

public enum PracticeKind: String, CaseIterable, Codable, Hashable, Sendable {
    case tuning
    case vibrato
    case bow
    case rhythm
    case repertoire
    case sightReading
    case fingerboard
    case earTraining
}

public struct PracticeRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let kind: PracticeKind
    public let startedAt: Date
    public let duration: TimeInterval
    public let score: Double?

    public init(
        id: UUID = UUID(),
        kind: PracticeKind,
        startedAt: Date,
        duration: TimeInterval,
        score: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.duration = max(0, duration)
        self.score = score
    }
}

public enum PracticeSummary {
    public static func seconds(
        on date: Date,
        records: [PracticeRecord],
        calendar: Calendar = .current
    ) -> TimeInterval {
        records
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.duration }
    }

    public static func secondsInWeek(
        containing date: Date,
        records: [PracticeRecord],
        calendar: Calendar = .current
    ) -> TimeInterval {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return records
            .filter { interval.contains($0.startedAt) }
            .reduce(0) { $0 + $1.duration }
    }

    public static func streak(
        asOf date: Date,
        records: [PracticeRecord],
        calendar: Calendar = .current
    ) -> Int {
        let practicedDays = Set(records.map { calendar.startOfDay(for: $0.startedAt) })
        var cursor = calendar.startOfDay(for: date)

        if !practicedDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  practicedDays.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while practicedDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
