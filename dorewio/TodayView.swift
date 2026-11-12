import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var history: PracticeHistoryStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    TodayHeader()
                    StudyModePicker()
                    DailyProgressSection()
                    DailyPlanSection()
                    StudioPrompt()
                }
                .padding(.horizontal, 16)
            }
            .contentMargins(.bottom, 96, for: .scrollContent)
            .background(PracticePalette.canvas)
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PracticeRoute.self, destination: PracticeDestination.view)
        }
    }
}

private struct TodayHeader: View {
    @EnvironmentObject private var history: PracticeHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(greeting)
                .font(.largeTitle.bold())
            Text(history.studyMode == .withViolin ? "先把琴调准，再完成今天的基本功。" : "没有带琴，也可以完成一节有效的短课。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "早上好"
        case 12..<18: "下午好"
        default: "晚上好"
        }
    }
}

private struct StudyModePicker: View {
    @EnvironmentObject private var history: PracticeHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今天的状态")
                .font(.headline)
            Picker("今天的状态", selection: $history.studyMode) {
                ForEach(StudyMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .accessibilityHint("选择后会切换今日学习计划")
    }
}

private struct DailyProgressSection: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 18) {
                    progressRing
                    progressDetails
                }
            } else {
                HStack(spacing: 20) {
                    progressRing
                    progressDetails
                }
            }
        }
        .practiceSurface(padding: 18)
        .accessibilityElement(children: .combine)
    }

    private var progressRing: some View {
        PracticeProgressRing(progress: progress)
            .frame(width: 104, height: 104)
    }

    private var progressDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(progress >= 1 ? "今日目标已完成" : (history.studyMode == .withViolin ? "今日练习" : "今日无琴课"))
                .font(.title3.bold())
            Text(progressDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("连续 \(history.currentStreak) 天", systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PracticePalette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todayMinutesText: String {
        guard history.todaySeconds > 0 else { return "0 分钟" }
        let minutes = Int(history.todaySeconds / 60)
        return minutes == 0 ? "不到 1 分钟" : "\(minutes) 分钟"
    }

    private var completedLearningTasks: Int {
        NoInstrumentCourse.tasks.filter { history.practicedToday($0.skill.practiceKind) }.count
    }

    private var progressDescription: String {
        if history.studyMode == .withoutViolin {
            return "已完成 \(completedLearningTasks) / \(NoInstrumentCourse.tasks.count) 项，约 10 分钟"
        }
        return "已练 \(todayMinutesText)，共 \(history.dailyGoalMinutes) 分钟"
    }

    private var progress: Double {
        if history.studyMode == .withoutViolin {
            return Double(completedLearningTasks) / Double(NoInstrumentCourse.tasks.count)
        }
        return min(1, history.todaySeconds / Double(max(1, history.dailyGoalMinutes * 60)))
    }
}

private struct PracticeProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(PracticePalette.hairline, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(PracticePalette.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress.formatted(.percent.precision(.fractionLength(0))))
                .font(.title3.bold().monospacedDigit())
        }
        .accessibilityHidden(true)
    }
}

private struct DailyPlanSection: View {
    @EnvironmentObject private var history: PracticeHistoryStore

    private let instrumentPlan: [(PracticeRoute, PracticeKind, String, String)] = [
        (.tuner, .tuning, "校准空弦", "3 分钟"),
        (.bow, .bow, "基础运弓", "10 分钟"),
        (.vibrato, .vibrato, "慢速揉弦", "8 分钟"),
        (.rhythm, .rhythm, "节奏稳定", "5 分钟")
    ]

    private let learningPlan: [(PracticeRoute, PracticeKind, String, String)] = [
        (.sightReading, .sightReading, "看谱认音", "2 分钟"),
        (.fingerboard, .fingerboard, "指板定位", "3 分钟"),
        (.rhythm, .rhythm, "节奏点击", "3 分钟"),
        (.earTraining, .earTraining, "空弦听辨", "2 分钟")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日计划").font(.title2.bold())
            ForEach(history.studyMode == .withViolin ? instrumentPlan : learningPlan, id: \.0) { route, kind, title, duration in
                PlanRow(route: route, kind: kind, title: title, duration: duration)
            }
        }
    }
}

private struct PlanRow: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    let route: PracticeRoute
    let kind: PracticeKind
    let title: String
    let duration: String

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                Image(systemName: history.practicedToday(kind) ? "checkmark.circle.fill" : kind.symbol)
                    .font(.title3)
                    .foregroundStyle(history.practicedToday(kind) ? PracticePalette.success : PracticePalette.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(kind.title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(history.practicedToday(kind) ? "已练" : duration)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(15)
            .background(PracticePalette.paper)
            .clipShape(.rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开\(kind.title)练习")
    }
}

private struct StudioPrompt: View {
    var body: some View {
        NavigationLink(value: PracticeRoute.studio) {
            HStack(spacing: 16) {
                Image(systemName: "waveform.badge.mic")
                    .font(.title2)
                    .foregroundStyle(PracticePalette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("练一首喜欢的曲子").font(.headline).foregroundStyle(.primary)
                    Text("导入音频、放慢循环并提取旋律").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill").font(.title2).foregroundStyle(PracticePalette.accent)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .practiceSurface(padding: 16)
    }
}
