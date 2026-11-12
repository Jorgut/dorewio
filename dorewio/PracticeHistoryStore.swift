import Combine
import Foundation

enum StudyMode: String, CaseIterable, Identifiable {
    case withViolin
    case withoutViolin

    var id: Self { self }

    var title: String {
        switch self {
        case .withViolin: "有琴"
        case .withoutViolin: "没带琴"
        }
    }

    var symbol: String {
        switch self {
        case .withViolin: "music.note"
        case .withoutViolin: "hand.tap"
        }
    }
}

@MainActor
final class PracticeHistoryStore: ObservableObject {
    @Published private(set) var records: [PracticeRecord]
    @Published var dailyGoalMinutes: Int {
        didSet { save() }
    }
    @Published var studyMode: StudyMode {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let recordsKey = "practice.records.v1"
    private let goalKey = "practice.dailyGoalMinutes"
    private let studyModeKey = "practice.studyMode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: recordsKey),
           let saved = try? JSONDecoder().decode([PracticeRecord].self, from: data) {
            records = saved.sorted { $0.startedAt > $1.startedAt }
        } else {
            records = []
        }
        let savedGoal = defaults.integer(forKey: goalKey)
        dailyGoalMinutes = savedGoal > 0 ? savedGoal : 30
        studyMode = StudyMode(rawValue: defaults.string(forKey: studyModeKey) ?? "") ?? .withoutViolin
    }

    var todaySeconds: TimeInterval {
        PracticeSummary.seconds(on: .now, records: records)
    }

    var currentStreak: Int {
        PracticeSummary.streak(asOf: .now, records: records)
    }

    var weeklySeconds: TimeInterval {
        PracticeSummary.secondsInWeek(containing: .now, records: records)
    }

    func practicedToday(_ kind: PracticeKind) -> Bool {
        records.contains { $0.kind == kind && Calendar.current.isDateInToday($0.startedAt) }
    }

    func record(
        _ kind: PracticeKind,
        startedAt: Date,
        duration: TimeInterval,
        score: Double? = nil
    ) {
        guard duration >= 1 else { return }
        records.insert(
            PracticeRecord(kind: kind, startedAt: startedAt, duration: duration, score: score),
            at: 0
        )
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where records.indices.contains(index) {
            records.remove(at: index)
        }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(records), forKey: recordsKey)
        defaults.set(dailyGoalMinutes, forKey: goalKey)
        defaults.set(studyMode.rawValue, forKey: studyModeKey)
    }
}

extension PracticeKind {
    var title: String {
        switch self {
        case .tuning: "调音"
        case .vibrato: "揉弦"
        case .bow: "运弓"
        case .rhythm: "节奏"
        case .repertoire: "曲目练习"
        case .sightReading: "基础识谱"
        case .fingerboard: "第一把位"
        case .earTraining: "空弦听辨"
        }
    }

    var symbol: String {
        switch self {
        case .tuning: "tuningfork"
        case .vibrato: "waveform.path"
        case .bow: "arrow.up.and.down"
        case .rhythm: "metronome"
        case .repertoire: "music.note.list"
        case .sightReading: "music.note"
        case .fingerboard: "rectangle.split.3x1"
        case .earTraining: "ear"
        }
    }
}
