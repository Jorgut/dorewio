import AVFoundation
import Combine
import Foundation

@MainActor
final class TunerSession: ObservableObject {
    @Published var concertA = 440.0
    @Published private(set) var state = ListeningState.idle
    @Published private(set) var reading: TunerReading?

    private let audioEngine = AudioPitchEngine()

    var isListening: Bool { state == .listening }

    func toggle() async {
        if isListening {
            stop()
            return
        }

        state = .requestingPermission
        guard await requestPermission() else {
            state = .permissionDenied
            return
        }

        do {
            try audioEngine.start { [weak self] frequency in
                Task { @MainActor in
                    guard let self else { return }
                    self.reading = TunerReading(frequency: frequency, concertA: self.concertA)
                }
            }
            state = .listening
        } catch {
            state = .failed
        }
    }

    func stop() {
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
}
