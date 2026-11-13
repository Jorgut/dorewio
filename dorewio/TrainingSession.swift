import AVFoundation
import Combine
import Foundation

struct TargetNote: Identifiable, Hashable, Sendable {
    let name: String
    let frequency: Double

    var id: String { name }

    static let choices = [
        TargetNote(name: "G3", frequency: 196.00),
        TargetNote(name: "D4", frequency: 293.66),
        TargetNote(name: "A4", frequency: 440.00),
        TargetNote(name: "E5", frequency: 659.25)
    ]
}

enum ListeningState: Equatable, Sendable {
    case idle
    case requestingPermission
    case listening
    case permissionDenied
    case failed
}

@MainActor
final class TrainingSession: ObservableObject {
    @Published var targetNote = TargetNote.choices[2]
    @Published private(set) var state = ListeningState.idle
    @Published private(set) var currentFrequency: Double?
    @Published private(set) var samples: [PitchSample] = []
    @Published private(set) var result: VibratoResult?

    private let audioEngine = AudioPitchEngine()
    private let analyzer = VibratoAnalyzer()
    private var startedAt: ContinuousClock.Instant?

    var isListening: Bool { state == .listening }

    func toggleListening() async {
        if isListening {
            stopListening()
        } else {
            await startListening()
        }
    }

    func resetForTargetChange() {
        samples = []
        currentFrequency = nil
        result = nil
        startedAt = .now
    }

    func stop() {
        stopListening()
    }

    private func startListening() async {
        state = .requestingPermission
        guard await requestPermission() else {
            state = .permissionDenied
            return
        }

        resetForTargetChange()
        do {
            try audioEngine.start { [weak self] frequency in
                Task { @MainActor in
                    self?.receive(frequency: frequency)
                }
            }
            state = .listening
        } catch {
            state = .failed
        }
    }

    private func stopListening() {
        audioEngine.stop()
        state = .idle
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func receive(frequency: Double) {
        currentFrequency = frequency
        guard let startedAt else { return }

        let cents = 1_200 * log2(frequency / targetNote.frequency)
        guard abs(cents) <= 200 else { return }

        let elapsed = startedAt.duration(to: .now).seconds
        samples.append(PitchSample(time: elapsed, centsFromTarget: cents))
        samples.removeAll { elapsed - $0.time > 3 }
        result = analyzer.analyze(samples: samples)
    }
}

private extension Duration {
    var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
