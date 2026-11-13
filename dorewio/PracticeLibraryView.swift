import SwiftUI

enum PracticeRoute: Hashable {
    case tuner
    case vibrato
    case bow
    case rhythm
    case studio
    case sightReading
    case fingerboard
    case earTraining
}

enum PracticeDestination {
    @ViewBuilder
    static func view(for route: PracticeRoute) -> some View {
        switch route {
        case .tuner: TunerView()
        case .vibrato: ProGate { VibratoPracticeView() }
        case .bow: ProGate { BowPracticeView() }
        case .rhythm: RhythmPracticeView()
        case .studio: ProGate { PracticeStudioView() }
        case .sightReading: SightReadingPracticeView()
        case .fingerboard: FingerboardPracticeView()
        case .earTraining: EarTrainingPracticeView()
        }
    }
}

struct PracticeLibraryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    PracticeSectionHeader(
                        eyebrow: "训练库",
                        title: "今天练什么",
                        detail: "从调音热身开始，再进入运弓、揉弦或节奏训练"
                    )
                    PracticeGroup(
                        title: "开始练琴",
                        items: [
                            (.tuner, "调音", "先让四根空弦回到中心", "tuningfork"),
                            (.rhythm, "节奏", "建立稳定的内部拍点", "metronome")
                        ],
                        proRoutes: []
                    )
                    PracticeGroup(
                        title: ProLaunchMode.gatingEnabled ? "技巧训练（Pro）" : "技巧训练",
                        items: [
                            (.bow, "运弓", "弓段、弓速与换弓控制", "arrow.up.and.down"),
                            (.vibrato, "揉弦", "速度、幅度与音高中心", "waveform.path")
                        ],
                        proRoutes: ProLaunchMode.gatingEnabled ? [.bow, .vibrato] : []
                    )
                }
                .padding()
            }
            .background(PracticePalette.canvas)
            .navigationTitle("训练")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PracticeRoute.self, destination: PracticeDestination.view)
        }
    }
}

private struct PracticeGroup: View {
    let title: String
    let items: [(PracticeRoute, String, String, String)]
    var proRoutes: Set<PracticeRoute> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            ForEach(items, id: \.0) { route, title, detail, symbol in
                NavigationLink(value: route) {
                    HStack(spacing: 15) {
                        Image(systemName: symbol)
                            .font(.title2)
                            .foregroundStyle(PracticePalette.accent)
                            .frame(width: 42, height: 42)
                            .background(PracticePalette.accent.opacity(0.09))
                            .clipShape(.rect(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(.headline).foregroundStyle(.primary)
                            Text(detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if proRoutes.contains(route) {
                            Text("PRO")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(PracticePalette.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(PracticePalette.accent.opacity(0.12), in: Capsule())
                                .accessibilityLabel("Pro 功能")
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(PracticePalette.paper)
                    .clipShape(.rect(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
