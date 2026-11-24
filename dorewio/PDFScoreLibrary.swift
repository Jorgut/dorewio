import Foundation
import PDFKit

/// 一份导入到本机的 PDF 曲谱。
struct PDFScore: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var fileName: String
    var pageCount: Int
    var importedAt: Date
}

/// 「曲目 → PDF 谱架」的本地存储：把 PDF 拷贝进 App 目录，离线查看，不上传。
@MainActor
final class PDFScoreLibrary: ObservableObject {
    @Published private(set) var scores: [PDFScore] = []
    @Published var errorMessage: String?

    private let folderURL: URL
    private let indexURL: URL
    private let fileManager: FileManager

    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let root = baseDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folder = root.appendingPathComponent("PDFScores", isDirectory: true)
        folderURL = folder
        indexURL = folder.appendingPathComponent("index.json")
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        load()
    }

    func fileURL(for score: PDFScore) -> URL {
        folderURL.appendingPathComponent(score.fileName)
    }

    /// 从文件选择器拿到的 PDF 拷贝进本机；原文件仍归「文件」App 管理。
    func importPDF(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            errorMessage = "这个文件不是可读取的 PDF，或 PDF 里没有页面。"
            return
        }

        let identifier = UUID()
        let fileExtension = url.pathExtension.isEmpty ? "pdf" : url.pathExtension.lowercased()
        let fileName = "\(identifier.uuidString).\(fileExtension)"
        let destination = folderURL.appendingPathComponent(fileName)

        do {
            try fileManager.copyItem(at: url, to: destination)
        } catch {
            errorMessage = "无法把 PDF 拷贝到本机：\(error.localizedDescription)"
            return
        }

        let title = url.deletingPathExtension().lastPathComponent
        let score = PDFScore(
            id: identifier,
            displayName: title.isEmpty ? "未命名 PDF" : title,
            fileName: fileName,
            pageCount: document.pageCount,
            importedAt: .now
        )
        scores.insert(score, at: 0)
        save()
    }

    func delete(_ score: PDFScore) {
        let url = fileURL(for: score)
        if fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                errorMessage = "无法删除这个 PDF：\(error.localizedDescription)"
                return
            }
        }
        scores.removeAll { $0.id == score.id }
        save()
    }

    // MARK: - 本地索引

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let stored = try? decoder.decode([PDFScore].self, from: data) else { return }

        let available = stored.filter { fileManager.fileExists(atPath: fileURL(for: $0).path) }
        scores = available
        if available.count != stored.count {
            save()
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(scores)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            errorMessage = "无法保存 PDF 目录：\(error.localizedDescription)"
        }
    }
}
