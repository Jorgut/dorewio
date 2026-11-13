import StoreKit
import SwiftUI

/// StoreKit 2 manager for the one-time "dorewio Pro" unlock.
///
/// The app is offline and account-free: the entitlement is derived from
/// `Transaction.currentEntitlements` and cached only for the current session.
@MainActor
final class ProStore: ObservableObject {
    static let productID = "com.archintera.VibratoCoach.pro.lifetime"

    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var message: String?
    /// Debug-only fallback so the paywall can be previewed in the simulator
    /// before the App Store product is approved.
    @Published var debugPreviewPrice: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("-paywallPreview") {
            debugPreviewPrice = "¥68"
        }
        #endif
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                await self.handle(result)
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var displayPrice: String? {
        product?.displayPrice
    }

    var isProductLoaded: Bool {
        product != nil
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            message = "暂时无法加载商品信息，请检查网络后重试。\n\(error.localizedDescription)"
        }
    }

    func purchase() async {
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            message = "商品暂不可用，请稍后再试。"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                case .unverified:
                    message = "购买校验失败，请稍后重试或恢复购买。"
                }
            case .userCancelled:
                break
            case .pending:
                message = "购买正在等待批准，完成后会自动解锁。"
            @unknown default:
                break
            }
        } catch {
            message = "购买失败：\(error.localizedDescription)"
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPro ? "已恢复购买，Pro 功能已解锁。" : "没有找到可恢复的购买记录。"
        } catch {
            message = "恢复购买失败：\(error.localizedDescription)"
        }
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        if case .verified(let transaction) = result {
            await transaction.finish()
        }
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }
}

/// Launch switch: with the Paid Apps Agreement not yet signed, build 9 ships as a
/// fully free app (no paywall). Flip to `true` for the paid 1.1 release.
enum ProLaunchMode {
    static let gatingEnabled = false
}

/// Wraps a Pro-only feature. Free users see the paywall instead.
struct ProGate<Content: View>: View {
    @EnvironmentObject private var proStore: ProStore
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if !ProLaunchMode.gatingEnabled || proStore.isPro {
            content
        } else {
            PaywallView()
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var proStore: ProStore
    @State private var showsError = false

    private let privacyURL = URL(string: "https://jorgut.github.io/dorewio/PRIVACY.html")!
    private let supportURL = URL(string: "https://jorgut.github.io/dorewio/SUPPORT.html")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                benefitsCard
                purchaseCard
                footnote
            }
            .padding(20)
        }
        .background(PracticePalette.canvas)
        .navigationTitle("dorewio Pro")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: proStore.message) {
            showsError = proStore.message != nil
        }
        .alert("提示", isPresented: $showsError) {
            Button("好", role: .cancel) { proStore.message = nil }
        } message: {
            Text(proStore.message ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dorewio.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("一次购买，永久解锁")
                .font(.title3.weight(.semibold))
            Text("免费版可以调音、完成第一课和使用基础练习；Pro 解锁全部训练与曲目工作室。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pro 包含")
                .font(.headline)
            benefit("music.note.list", "乐谱导入与跟奏", "导入 MusicXML / MXL，按谱发声、显示弦与指号，支持变速、循环、节拍器与预备拍。")
            benefit("waveform", "音频导入与扒谱", "导入音频、放慢循环，并提取单旋律生成可跟练的谱。")
            benefit("figure.walk", "全部技巧训练", "运弓、揉弦、音准等进阶训练不再受限。")
            benefit("chart.line.uptrend.xyaxis", "完整练习统计", "查看历史练习时长与各技能进步趋势。")
        }
        .practiceSurface(padding: 18)
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(PracticePalette.accent)
                .frame(width: 36, height: 36)
                .background(PracticePalette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var purchaseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(proStore.displayPrice ?? proStore.debugPreviewPrice ?? "加载中…")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("一次性购买")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await proStore.purchase() }
            } label: {
                HStack {
                    if proStore.isLoading {
                        ProgressView().tint(.white)
                    }
                    Text((proStore.isProductLoaded || proStore.debugPreviewPrice != nil) ? "解锁 Pro" : "正在加载商品…")
                        .font(.headline)
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(PracticePalette.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(proStore.isLoading || (!proStore.isProductLoaded && proStore.debugPreviewPrice == nil))

            Button {
                Task { await proStore.restore() }
            } label: {
                Text("恢复购买")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)

            Text("购买绑定你的 Apple ID，可在同一 Apple ID 的设备上恢复；无订阅、无自动续费。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .practiceSurface(padding: 18)
    }

    private var footnote: some View {
        HStack(spacing: 16) {
            Link("隐私政策", destination: privacyURL)
            Link("使用支持", destination: supportURL)
        }
        .font(.caption)
        .foregroundStyle(PracticePalette.accent)
    }
}
