import PDFKit
import SwiftUI

/// 只读 PDF 谱面：PDFKit 渲染，支持连续滚动、双指缩放，离线可用。
struct PDFScoreViewer: View {
    let score: PDFScore
    let fileURL: URL

    @State private var document: PDFDocument?
    @State private var loadFailed = false
    @State private var viewBox = PDFViewBox()
    @State private var currentPage = 1

    var body: some View {
        Group {
            if let document {
                PDFKitView(document: document, viewBox: viewBox)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("PDF 谱面：\(score.displayName)，共 \(score.pageCount) 页")
            } else if loadFailed {
                ContentUnavailableView {
                    Label("无法打开这份 PDF", systemImage: "doc.questionmark")
                } description: {
                    Text("文件可能已被删除或损坏，请回到谱架重新导入。")
                }
            } else {
                ProgressView("正在打开…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PracticePalette.canvas)
        .navigationTitle(score.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .task { load() }
        .onReceive(NotificationCenter.default.publisher(for: .PDFViewPageChanged)) { _ in
            syncCurrentPage()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 4) {
            Button {
                viewBox.view?.goToPreviousPage(nil)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("上一页")
            .disabled(document == nil)

            Button {
                viewBox.view?.goToNextPage(nil)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("下一页")
            .disabled(document == nil)

            Spacer(minLength: 8)

            Text(document == nil
                 ? "共 \(score.pageCount) 页 · 离线查看"
                 : "第 \(currentPage) / \(score.pageCount) 页 · 离线查看")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("第 \(currentPage) 页，共 \(score.pageCount) 页")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func load() {
        guard document == nil, !loadFailed else { return }
        if let loaded = PDFDocument(url: fileURL) {
            document = loaded
        } else {
            loadFailed = true
        }
    }

    private func syncCurrentPage() {
        guard let page = viewBox.view?.currentPage?.pageRef?.pageNumber,
              page != currentPage else { return }
        currentPage = min(max(page, 1), max(score.pageCount, 1))
    }
}

/// PDFView 的弱引用盒，让 SwiftUI 工具条可以调用翻页，而不必持有 UIKit 视图。
final class PDFViewBox {
    weak var view: PDFView?
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let viewBox: PDFViewBox

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = true
        view.backgroundColor = .systemGroupedBackground
        viewBox.view = view
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
        viewBox.view = view
    }
}
