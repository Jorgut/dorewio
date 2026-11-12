import SwiftUI

enum PracticePalette {
    static let accent = Color(red: 0.78, green: 0.16, blue: 0.12)
    static let success = Color(red: 0.08, green: 0.48, blue: 0.39)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let paper = Color(uiColor: .secondarySystemGroupedBackground)
    static let hairline = Color.primary.opacity(0.10)
}

struct PracticeSectionHeader: View {
    let eyebrow: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(PracticePalette.accent)
            Text(title)
                .font(.title2.weight(.bold))
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct PracticeSurface: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PracticePalette.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(PracticePalette.hairline, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 7))
    }
}

extension View {
    func practiceSurface(padding: CGFloat = 16) -> some View {
        modifier(PracticeSurface(padding: padding))
    }
}

struct PracticeMetric: View {
    let label: String
    let value: String
    let unit: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct PressablePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(PracticePalette.accent.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(.rect(cornerRadius: 7))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}
