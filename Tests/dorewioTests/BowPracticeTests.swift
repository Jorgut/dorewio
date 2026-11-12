import Testing
@testable import VibratoCore

struct BowPracticeCurriculumTests {
    @Test("每个节奏变体的动作时值等于标注拍数")
    func rhythmDurationsMatchDeclaredBeats() {
        for exercise in BowPracticeCurriculum.rhythmExercises {
            #expect(exercise.eventDuration == exercise.totalBeats)
        }
    }

    @Test("节奏型二使用四个十六分音符和两个八分音符")
    func patternTwoUsesTwoEighthNotes() throws {
        let exercise = try #require(
            BowPracticeCurriculum.rhythmExercises.first { $0.id == "rhythm-2-normal" }
        )

        #expect(exercise.events.map(\.durationBeats) == [0.25, 0.25, 0.25, 0.25, 0.5, 0.5])
        #expect(exercise.events.map(\.bowFraction) == [0.25, 0.25, 0.25, 0.25, 0.5, 0.5])
        #expect(exercise.totalBeats == 2)
    }

    @Test("放慢版本保留原节奏比例")
    func slowedVariantsPreserveRhythmRatio() throws {
        let normal = try exercise(id: "rhythm-1-normal")
        let double = try exercise(id: "rhythm-1-slow-2")
        let quadruple = try exercise(id: "rhythm-1-slow-4")

        #expect(double.events.map(\.durationBeats) == normal.events.map { $0.durationBeats * 2 })
        #expect(quadruple.events.map(\.durationBeats) == normal.events.map { $0.durationBeats * 4 })
    }

    @Test("附点节奏慢速版仍为两个动作")
    func dottedSlowVariantUsesOneFinalEighth() throws {
        let exercise = try exercise(id: "rhythm-3-slow-2")

        #expect(exercise.events.map(\.durationBeats) == [1.5, 0.5])
        #expect(exercise.totalBeats == 2)
    }

    @Test("课程包含四项基础练习和五种节奏型")
    func curriculumContainsSuppliedMaterial() {
        #expect(BowPracticeCurriculum.basicExercises.count == 4)
        #expect(Set(BowPracticeCurriculum.rhythmExercises.map(\.patternNumber)) == Set(1...5))
        #expect(BowPracticeCurriculum.allExercises.count == 13)
    }

    @Test("弓向和弓段使用可直接朗读的名称")
    func providesDisplayNames() {
        #expect(BowDirection.down.symbol == "↓")
        #expect(BowDirection.down.chineseName == "下弓")
        #expect(BowDirection.up.symbol == "↑")
        #expect(BowDirection.up.chineseName == "上弓")
        #expect(BowEvent(durationBeats: 1, bowFraction: 1, cue: "").bowLengthName == "全弓")
        #expect(BowEvent(durationBeats: 1, bowFraction: 0.75, cue: "").bowLengthName == "3/4 弓")
        #expect(BowEvent(durationBeats: 1, bowFraction: 0.5, cue: "").bowLengthName == "半弓")
        #expect(BowEvent(durationBeats: 1, bowFraction: 0.25, cue: "").bowLengthName == "1/4 弓")
        #expect(BowEvent(durationBeats: 1, bowFraction: 1.0 / 3, cue: "").bowLengthName == "0.33 弓")
    }

    private func exercise(id: String) throws -> BowExercise {
        try #require(BowPracticeCurriculum.rhythmExercises.first { $0.id == id })
    }
}

struct BowPracticeProgressTests {
    private let exercise = BowExercise(
        id: "test",
        category: .rhythm,
        title: "测试",
        detail: "",
        rhythmNotation: "",
        mnemonic: "da da",
        patternNumber: 1,
        events: [
            BowEvent(durationBeats: 0.5, bowFraction: 0.5, cue: "da"),
            BowEvent(durationBeats: 0.25, bowFraction: 0.25, cue: "da")
        ]
    )

    @Test("推进动作时交替弓向并在末尾循环")
    func advancesAndWraps() {
        var progress = BowPracticeProgress(exercise: exercise)

        #expect(progress.eventIndex == 0)
        #expect(progress.direction == .down)

        progress.advance()
        #expect(progress.eventIndex == 1)
        #expect(progress.direction == .up)
        #expect(progress.completedCycles == 0)

        progress.advance()
        #expect(progress.eventIndex == 0)
        #expect(progress.direction == .down)
        #expect(progress.completedCycles == 1)
    }

    @Test("重置后回到第一个下弓动作")
    func resets() {
        var progress = BowPracticeProgress(exercise: exercise)
        progress.advance()
        progress.reset()

        #expect(progress.eventIndex == 0)
        #expect(progress.direction == .down)
        #expect(progress.completedCycles == 0)
    }

    @Test("当前动作可读取，空序列不会越界")
    func handlesCurrentAndEmptyEvents() {
        let progress = BowPracticeProgress(exercise: exercise)
        #expect(progress.currentEvent == exercise.events[0])
        #expect(exercise.totalBeats == 0.75)

        let emptyExercise = BowExercise(
            id: "empty",
            category: .basic,
            title: "空",
            detail: "",
            rhythmNotation: "",
            mnemonic: "",
            patternNumber: nil,
            events: []
        )
        var emptyProgress = BowPracticeProgress(exercise: emptyExercise)
        emptyProgress.advance()

        #expect(emptyProgress.currentEvent == nil)
        #expect(emptyProgress.eventIndex == 0)
        #expect(emptyProgress.completedCycles == 0)
    }
}
