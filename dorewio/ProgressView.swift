import SwiftUI

struct PracticeProgressView: View {
    @EnvironmentObject private var history: PracticeHistoryStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ProgressSummary()
                    WeeklyPracticeChart()
                    SkillProgressSection()
                    GoalEditor()
                    RecentPracticeList()
                }
                .padding()
            }
            .background(PracticePalette.canvas)
            .navigationTitle("进度")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SkillProgressSection: View {
    @EnvironmentObject private var history: PracticeHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("学习能力").font(.title3.bold())
                Text("不只看时长，也看每项能力的正确率")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(LearningSkill.allCases, id: \.self) { skill in
                let summary = LearningProgress.summary(for: skill, records: history.records)
                HStack(spacing: 12) {
                    Image(systemName: skill.symbol)
                        .foregroundStyle(PracticePalette.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(skill.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(scoreText(summary.averageScore))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                        ProgressView(value: (summary.averageScore ?? 0) / 100)
                            .tint(summary.averageScore == nil ? Color.secondary : PracticePalette.success)
                    }
                    Text("\(summary.completedSessions) 次")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(skill.title)，\(summary.completedSessions) 次，\(scoreText(summary.averageScore))")
            }
        }
        .practiceSurface()
    }

    private func scoreText(_ score: Double?) -> String {
        guard let score else { return "待开始" }
        return "\(Int(score.rounded()))%"
    }
}

private struct ProgressSummary: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) { metrics }
            } else {
                HStack(spacing: 10) { metrics }
            }
        }
        .practiceSurface()
    }

    @ViewBuilder
    private var metrics: some View {
        PracticeMetric(label: "连续练习", value: "\(history.currentStreak)", unit: "天", tint: PracticePalette.accent)
        PracticeMetric(label: "本周", value: weeklyMinutesText, unit: "分钟")
        PracticeMetric(label: "总次数", value: "\(history.records.count)", unit: "次")
    }

    private var weeklyMinutesText: String {
        guard history.weeklySeconds > 0 else { return "0" }
        let minutes = Int(history.weeklySeconds / 60)
        return minutes == 0 ? "不到 1" : "\(minutes)"
    }
}

private struct WeeklyPracticeChart: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近 7 天").font(.title3.bold())
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let seconds = PracticeSummary.seconds(on: day, records: history.records)
                    VStack(spacing: 7) {
                        Text(seconds > 0 ? minuteValue(seconds) : "")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(height: 14)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(seconds > 0 ? PracticePalette.accent : PracticePalette.hairline)
                            .frame(height: max(5, CGFloat(seconds / maxSeconds) * 92))
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide)))，练习 \(minuteValue(seconds)) 分钟")
                }
            }
            .frame(height: 132, alignment: .bottom)
        }
        .practiceSurface()
    }

    private var days: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private var maxSeconds: TimeInterval {
        max(60, days.map { PracticeSummary.seconds(on: $0, records: history.records) }.max() ?? 60)
    }

    private func minuteValue(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes == 0 && seconds > 0 ? "不到 1" : "\(minutes)"
    }
}

private struct GoalEditor: View {
    @EnvironmentObject private var history: PracticeHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("每日目标") {
                Stepper("\(history.dailyGoalMinutes) 分钟", value: $history.dailyGoalMinutes, in: 10...120, step: 5)
                    .monospacedDigit()
            }
            Text("目标只用于提醒和计算今日进度，可以随时调整。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .practiceSurface()
    }
}

private struct RecentPracticeList: View {
    @EnvironmentObject private var history: PracticeHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近练习").font(.title3.bold())
            if history.records.isEmpty {
                ContentUnavailableView(
                    "还没有练习记录",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("完成一次调音或技巧练习后会出现在这里。")
                )
                .frame(maxWidth: .infinity)
                .practiceSurface()
            } else {
                ForEach(history.records.prefix(12)) { record in
                    HStack(spacing: 13) {
                        Image(systemName: record.kind.symbol)
                            .foregroundStyle(PracticePalette.accent)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.kind.title).font(.headline)
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(duration(record.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return minutes > 0 ? "\(minutes) 分钟" : "\(max(1, Int(seconds))) 秒"
    }
}
