import SwiftUI

/// 「曲目」页的 PDF 谱架：导入 PDF、离线翻谱、管理本机副本。
struct PDFShelfView: View {
    @ObservedObject var library: PDFScoreLibrary
    let importAction: () -> Void

    @State private var pendingDeletion: PDFScore?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if library.scores.isEmpty {
                emptyState
            } else {
                scoreList
                importButton
            }
        }
        .practiceSurface()
        .confirmationDialog(
            "删除这份 PDF？",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let score = pendingDeletion {
                    library.delete(score)
                }
                pendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("只会删除 App 内的副本，不影响「文件」里的原 PDF。")
        }
        .alert("PDF 提示", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    // MARK: - 标题

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("PDF 谱架")
                        .font(.headline)
                    if !library.scores.isEmpty {
                        Text("\(library.scores.count) 份")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PracticePalette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(PracticePalette.accent.opacity(0.10))
                            .clipShape(.capsule)
                    }
                }
                Text("导入 PDF 曲谱，离线翻看，不会上传")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if !library.scores.isEmpty {
                Button("导入", systemImage: "plus", action: importAction)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(minHeight: 44)
                    .accessibilityLabel("导入 PDF 曲谱")
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(PracticePalette.accent)
                    .frame(width: 52, height: 52)
                    .background(PracticePalette.accent.opacity(0.10))
                    .clipShape(.rect(cornerRadius: 7))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("还没有 PDF 曲谱")
                        .font(.subheadline.weight(.semibold))
                    Text("把老师发来的谱、考级谱或 PDF 教材放进「文件」，这里导入即可离线翻看。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("导入 PDF", systemImage: "square.and.arrow.down", action: importAction)
                .buttonStyle(.borderedProminent)
                .tint(PracticePalette.accent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityHint("从「文件」中选择一份 PDF")
        }
    }

    // MARK: - 列表

    private var scoreList: some View {
        VStack(spacing: 0) {
            ForEach(library.scores) { score in
                row(score)
                if score.id != library.scores.last?.id {
                    Divider()
                }
            }
        }
    }

    private func row(_ score: PDFScore) -> some View {
        HStack(spacing: 10) {
            NavigationLink(value: score) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(PracticePalette.accent)
                        .frame(width: 36, height: 44)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(score.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(score.pageCount) 页 · \(score.importedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(score.displayName)，\(score.pageCount) 页")
            .accessibilityHint("打开 PDF 谱面")

            Menu {
                Button("删除", systemImage: "trash", role: .destructive) {
                    pendingDeletion = score
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("\(score.displayName) 的操作")
        }
    }

    private var importButton: some View {
        Button("导入 PDF", systemImage: "square.and.arrow.down", action: importAction)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .accessibilityHint("从「文件」中选择一份 PDF")
    }
}
