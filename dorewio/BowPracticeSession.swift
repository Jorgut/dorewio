import Combine
import Foundation

@MainActor
final class BowPracticeSession: ObservableObject {
    @Published var selectedExercise: BowExercise {
        didSet {
            guard selectedExercise.id != oldValue.id else { return }
            stop()
            progress = BowPracticeProgress(exercise: selectedExercise)
        }
    }
    @Published var bpm = 72.0
    @Published private(set) var progress: BowPracticeProgress
    @Published private(set) var isRunning = false
    @Published private(set) var beatPulse = 0
    @Published private(set) var motionPulse = 0

    private var eventTask: Task<Void, Never>?
    private var beatTask: Task<Void, Never>?

    init(exercise: BowExercise = BowPracticeCurriculum.basicExercises[0]) {
        selectedExercise = exercise
        progress = BowPracticeProgress(exercise: exercise)
    }

    var currentEvent: BowEvent? { progress.currentEvent }

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard !isRunning, currentEvent != nil else { return }
        isRunning = true
        beatPulse += 1
        motionPulse += 1

        eventTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let event = self.currentEvent else { return }
                do {
                    try await Task.sleep(for: .seconds(self.seconds(for: event.durationBeats)))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self.progress.advance()
                self.motionPulse += 1
            }
        }

        beatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await Task.sleep(for: .seconds(self.seconds(for: 1)))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self.beatPulse += 1
            }
        }
    }

    func stop() {
        eventTask?.cancel()
        beatTask?.cancel()
        eventTask = nil
        beatTask = nil
        isRunning = false
    }

    func reset() {
        stop()
        progress.reset()
    }

    private func seconds(for beats: Double) -> Double {
        beats * 60 / bpm
    }
}
