import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let privacyURL = URL(string: "https://jorgut.github.io/dorewio/PRIVACY.html")!
    private let supportURL = URL(string: "https://jorgut.github.io/dorewio/SUPPORT.html")!

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("dorewio.")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Learn music. Play with confidence.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("版本 \(version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("关于")
                        .font(.headline)
                    Text("一款离线的小提琴自学 App：调音、音准、节奏、识谱、把位（1–7）、听辨，以及导入 MusicXML/MXL 乐谱直接跟奏。无需账号，练习数据只保存在本机。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .practiceSurface(padding: 18)

                VStack(alignment: .leading, spacing: 12) {
                    Link(destination: privacyURL) {
                        row("隐私政策", symbol: "lock.shield")
                    }
                    Link(destination: supportURL) {
                        row("使用支持", symbol: "questionmark.circle")
                    }
                }
                .practiceSurface(padding: 18)

                Text("App 备案号：办理中（取得后在此展示）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(PracticePalette.canvas)
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }

    private func row(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(PracticePalette.accent)
                .frame(width: 24)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
