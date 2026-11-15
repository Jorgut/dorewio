import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dorewio.language") private var language = "system"

    private let privacyURL = URL(string: "https://jorgut.github.io/dorewio/PRIVACY.html")!
    private let supportURL = URL(string: "https://jorgut.github.io/dorewio/SUPPORT.html")!

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image("BrandMark")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(.rect(cornerRadius: 10))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dorewio.")
                            .font(.title3.bold())
                        Text("Learn music. Play with confidence.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("语言") {
                Picker("界面语言", selection: $language) {
                    Text("跟随系统").tag("system")
                    Text("简体中文").tag("zh-Hans")
                    Text("English（开发中）").tag("en").disabled(true)
                }
                Text("当前版本界面为简体中文；英文界面会在后续版本提供。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                NavigationLink("关于 dorewio") {
                    AboutView()
                }
                Link("隐私政策", destination: privacyURL)
                Link("使用支持", destination: supportURL)
                LabeledContent("版本", value: versionString)
            }

            Section {
                Text("dorewio. designed by archintera")
                    .font(.footnote.weight(.semibold))
                Text("© 2026 archintera. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
