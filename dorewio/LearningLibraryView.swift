import SwiftUI

struct LearningLibraryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PracticeSectionHeader(
                        eyebrow: "无琴学习",
                        title: "现在没有琴，也能有效进步",
                        detail: "用十分钟建立识谱、指板、节奏和听辨之间的连接"
                    )
                    DailyCourseCard()
                    DorewioLessonEntry()
                    LearningModuleGroup()
                    LearningTipCard()
                }
                .padding()
            }
            .background(PracticePalette.canvas)
            .navigationTitle("学习")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PracticeRoute.self, destination: PracticeDestination.view)
        }
    }
}

private struct DailyCourseCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("今日无琴课", systemImage: "clock.badge.checkmark")
                    .font(.title3.bold())
                Spacer()
                Text("10 分钟")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PracticePalette.accent)
            }
            ForEach(Array(NoInstrumentCourse.tasks.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(PracticePalette.accent)
                        .clipShape(.circle)
                    Text(task.skill.title)
                    Spacer()
                    Text("\(task.minutes) 分钟")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .practiceSurface(padding: 18)
        .accessibilityElement(children: .combine)
    }
}


private struct DorewioLessonEntry: View {
    var body: some View {
        NavigationLink {
            DorewioLessonView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("dorewio.")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("第一课")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PracticePalette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PracticePalette.accent.opacity(0.10), in: Capsule())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text("从零开始：F5（Fa）、E 弦低一指与四条空弦")
                    .font(.headline)
                Text("看一个音名，在指板上找到琴弦和手指位置，再听参考音核对。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.white, PracticePalette.accent.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(PracticePalette.accent.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开 dorewio 第一课")
    }
}

private struct LearningModuleGroup: View {
    private let modules: [(PracticeRoute, LearningSkill, String)] = [
        (.sightReading, .sightReading, "看五线谱，快速说出音名"),
        (.fingerboard, .fingerboard, "把音名定位到弦和手指"),
        (.rhythm, .rhythm, "跟随目标速度点击拍点"),
        (.earTraining, .earTraining, "听出 G、D、A、E 空弦")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("开始训练").font(.title3.bold())
            ForEach(modules, id: \.0) { route, skill, detail in
                NavigationLink(value: route) {
                    HStack(spacing: 14) {
                        Image(systemName: skill.symbol)
                            .font(.title3)
                            .foregroundStyle(PracticePalette.accent)
                            .frame(width: 42, height: 42)
                            .background(PracticePalette.accent.opacity(0.09))
                            .clipShape(.rect(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(skill.title).font(.headline).foregroundStyle(.primary)
                            Text(detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(PracticePalette.paper)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LearningTipCard: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("学习建议").font(.headline)
                Text("先看谱认音，再在指板上定位，最后用耳朵确认。不要只背答案。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "lightbulb.max.fill")
                .foregroundStyle(PracticePalette.accent)
        }
        .practiceSurface()
    }
}

extension LearningSkill {
    var title: String {
        switch self {
        case .sightReading: "基础识谱"
        case .fingerboard: "第一把位"
        case .rhythm: "节奏点击"
        case .earTraining: "空弦听辨"
        }
    }

    var symbol: String {
        switch self {
        case .sightReading: "music.note"
        case .fingerboard: "rectangle.split.3x1"
        case .rhythm: "hand.tap"
        case .earTraining: "ear"
        }
    }
}
