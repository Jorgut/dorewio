import SwiftUI

struct PitchTraceView: View {
    let samples: [PitchSample]
    let targetName: String

    var body: some View {
        Canvas { context, size in
            drawGuides(context: &context, size: size)
            drawTrace(context: &context, size: size)
        }
        .frame(minHeight: 220)
        .background(Color(uiColor: .secondarySystemBackground))
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("音高曲线，目标音 \(targetName)")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let latest = samples.last else { return "等待演奏" }
        return latest.centsFromTarget.formatted(
            .number.precision(.fractionLength(0)).sign(strategy: .always())
        ) + " 音分"
    }

    private func drawGuides(context: inout GraphicsContext, size: CGSize) {
        for cents in stride(from: -100.0, through: 100.0, by: 25) {
            let y = yPosition(for: cents, height: size.height)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            let isCenter = cents == 0
            context.stroke(
                path,
                with: .color(isCenter ? .green.opacity(0.8) : .secondary.opacity(0.18)),
                style: StrokeStyle(lineWidth: isCenter ? 2 : 1, dash: isCenter ? [] : [4, 6])
            )
        }
    }

    private func drawTrace(context: inout GraphicsContext, size: CGSize) {
        guard samples.count > 1, let latestTime = samples.last?.time else { return }
        let earliestTime = max(0, latestTime - 3)
        var path = Path()

        for (index, sample) in samples.enumerated() {
            let progress = (sample.time - earliestTime) / 3
            let point = CGPoint(
                x: max(0, min(1, progress)) * size.width,
                y: yPosition(for: sample.centsFromTarget, height: size.height)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        context.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    private func yPosition(for cents: Double, height: CGFloat) -> CGFloat {
        let clamped = max(-100, min(100, cents))
        return height * CGFloat(0.5 - clamped / 200)
    }
}
