import SwiftUI

/// Stylized violin fingerboard from the scroll: nut at top, body below.
/// G D A E are labeled left to right. These are note positions, not frets.
struct FingerboardView: View {
    let selected: FingerChoice?
    let answer: FingerChoice
    let revealAnswer: Bool
    let onTap: (FingerChoice) -> Void

    private let red = Color(red: 0.74, green: 0.24, blue: 0.20)
    private let fingerSteps = [0, 1, 3, 5, 7]

    var body: some View {
        GeometryReader { geometry in
            let center = geometry.size.width / 2
            let halfSpacing: CGFloat = min(geometry.size.width * 0.095, 39)
            let xs = [center - 3 * halfSpacing, center - halfSpacing,
                      center + halfSpacing, center + 3 * halfSpacing]
            let nutY: CGFloat = 66
            let neckLength: CGFloat = min(geometry.size.height - 120, 300)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.14, green: 0.16, blue: 0.18))
                    .frame(width: xs[3] - xs[0] + 55, height: neckLength + 52)
                    .position(x: center, y: nutY + (neckLength + 52) / 2 - 2)

                Text("琴头 · SCROLL ↑")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .position(x: center, y: 19)

                ForEach(Array(ViolinString.allCases.enumerated()), id: \.element.id) { index, string in
                    Text(string.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .position(x: xs[index], y: nutY - 25)

                    Path { path in
                        path.move(to: CGPoint(x: xs[index], y: nutY))
                        path.addLine(to: CGPoint(x: xs[index], y: nutY + neckLength))
                    }
                    .stroke(Color(white: 0.85), style: StrokeStyle(lineWidth: CGFloat(3.1 - Double(index) * 0.65)))
                }

                Path { path in
                    path.move(to: CGPoint(x: xs[0] - 23, y: nutY))
                    path.addLine(to: CGPoint(x: xs[3] + 23, y: nutY))
                }
                .stroke(.white, lineWidth: 7)

                ForEach(Array(ViolinString.allCases.enumerated()), id: \.element.id) { index, string in
                    ForEach(0..<fingerSteps.count, id: \.self) { finger in
                        let candidate = FingerChoice(string: string, finger: finger)
                        let y = nutY + noteOffset(fingerSteps[finger], available: neckLength)
                        let isSelected = selected == candidate
                        let isAnswer = revealAnswer && answer == candidate
                        Button {
                            onTap(candidate)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(isAnswer ? Color.green : isSelected ? red : Color.white.opacity(0.18))
                                    .frame(width: 33, height: 33)
                                Circle()
                                    .strokeBorder(.white.opacity(isSelected || isAnswer ? 0.95 : 0.42), lineWidth: 1.5)
                                    .frame(width: 33, height: 33)
                                Text(finger == 0 ? "○" : "\(finger)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(string.rawValue) 弦，\(finger == 0 ? "空弦" : "第 \(finger) 指")")
                        .position(x: xs[index], y: y)
                    }
                }

                Text("琴身 · BODY ↓")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .position(x: center, y: geometry.size.height - 15)
            }
        }
        .frame(height: 410)
    }

    private func noteOffset(_ semitones: Int, available: CGFloat) -> CGFloat {
        let normalized = 1.0 - pow(2.0, -Double(semitones) / 12.0)
        return CGFloat(normalized / (1.0 - pow(2.0, -7.0 / 12.0))) * (available - 28)
    }
}
