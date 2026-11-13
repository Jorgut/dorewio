import SwiftUI

struct BowPracticeView: View {
    @EnvironmentObject private var history: PracticeHistoryStore
    @StateObject private var session = BowPracticeSession()
    @State private var category = BowExerciseCategory.basic
    @State private var practiceStartedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PracticeSectionHeader(
                    eyebrow: "右手",
                    title: "把弓速和弓段练成肌肉记忆",
                    detail: "跟随方向与口令，不要为了追拍牺牲音色"
                )
                ExerciseSelectionSection(session: session, category: $category)
                TempoSection(session: session)
                BowMotionSection(session: session)
                ExerciseDetailSection(exercise: session.selectedExercise)
                BowPracticeControls(session: session)
            }
            .padding()
        }
        .background(PracticePalette.canvas)
        .navigationTitle("运弓练习")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: session.beatPulse)
        .onChange(of: session.isRunning) { updatePracticeTimer(isActive: session.isRunning) }
        .onDisappear {
            finishPractice()
            session.stop()
        }
    }

    private func updatePracticeTimer(isActive: Bool) {
        if isActive {
            practiceStartedAt = practiceStartedAt ?? .now
        } else {
            finishPractice()
        }
    }

    private func finishPractice() {
        guard let startedAt = practiceStartedAt else { return }
        history.record(.bow, startedAt: startedAt, duration: Date.now.timeIntervalSince(startedAt))
        practiceStartedAt = nil
    }
}

private struct ExerciseSelectionSection: View {
    @ObservedObject var session: BowPracticeSession
    @Binding var category: BowExerciseCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("练习类型", selection: $category) {
                Text("基础").tag(BowExerciseCategory.basic)
                Text("节奏型").tag(BowExerciseCategory.rhythm)
            }
            .pickerStyle(.segmented)

            Picker("练习项目", selection: $session.selectedExercise) {
                ForEach(exercises) { exercise in
                    Text(exercise.title).tag(exercise)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: category) {
            guard let first = exercises.first else { return }
            session.selectedExercise = first
        }
        .practiceSurface()
    }

    private var exercises: [BowExercise] {
        switch category {
        case .basic: BowPracticeCurriculum.basicExercises
        case .rhythm: BowPracticeCurriculum.rhythmExercises
        }
    }
}

private struct TempoSection: View {
    @ObservedObject var session: BowPracticeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("速度") {
                Text("\(Int(session.bpm)) BPM")
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
            Slider(value: $session.bpm, in: 40...160, step: 1) {
                Text("速度")
            } minimumValueLabel: {
                Text("40")
            } maximumValueLabel: {
                Text("160")
            }
            .tint(PracticePalette.accent)
            .accessibilityValue("每分钟 \(Int(session.bpm)) 拍")
        }
        .practiceSurface()
    }
}

private struct BowMotionSection: View {
    @ObservedObject var session: BowPracticeSession

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: session.progress.direction == .down ? "arrow.down" : "arrow.up")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PracticePalette.accent)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, value: session.motionPulse)
                .accessibilityHidden(true)

            Text("\(session.progress.direction.chineseName) \(session.progress.direction.symbol)")
                .font(.title.weight(.bold))

            Text(session.currentEvent?.bowLengthName ?? "--")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(session.currentEvent?.cue ?? "--")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(PracticePalette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(stepDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .practiceSurface(padding: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var stepDescription: String {
        let count = session.selectedExercise.events.count
        return "动作 \(session.progress.eventIndex + 1) / \(count) · 完成 \(session.progress.completedCycles) 轮"
    }

    private var accessibilityDescription: String {
        let event = session.currentEvent
        return "\(session.progress.direction.chineseName)，\(event?.bowLengthName ?? "")，口令 \(event?.cue ?? "")，\(stepDescription)"
    }
}

private struct ExerciseDetailSection: View {
    let exercise: BowExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.title)
                .font(.headline)
            Text(exercise.rhythmNotation)
                .font(.title3.weight(.medium))
            Text(exercise.mnemonic)
                .font(.body.weight(.semibold))
                .foregroundStyle(PracticePalette.accent)
            Text(exercise.detail)
                .font(.body)
                .foregroundStyle(.secondary)
            Text("一轮 \(formattedBeats) 拍")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .practiceSurface()
        .accessibilityElement(children: .combine)
    }

    private var formattedBeats: String {
        exercise.totalBeats.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private struct BowPracticeControls: View {
    @ObservedObject var session: BowPracticeSession

    var body: some View {
        HStack(spacing: 12) {
            Button(action: session.reset) {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("重置练习")

            Button(action: session.toggle) {
                Label(
                    session.isRunning ? "暂停" : "开始",
                    systemImage: session.isRunning ? "pause.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressablePrimaryButtonStyle())
        }
    }
}
