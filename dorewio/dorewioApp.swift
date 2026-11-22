import SwiftUI
#if DEBUG
import UIKit
#endif

@main
struct DorewioApp: App {
    @StateObject private var history = PracticeHistoryStore()
    @StateObject private var proStore = ProStore()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if CommandLine.arguments.contains("-lessonPreview") {
                    NavigationStack { DorewioLessonView() }
                } else if CommandLine.arguments.contains("-paywallPreview") {
                    NavigationStack {
                        PaywallView()
                    }
                } else if CommandLine.arguments.contains("-fingerboardPreview") {
                    NavigationStack {
                        FingerboardPracticeView()
                    }
                } else if CommandLine.arguments.contains("-metronomePreview") {
                    NavigationStack {
                        MetronomeView()
                    }
                } else if CommandLine.arguments.contains("-settingsPreview") {
                    NavigationStack { SettingsView() }
                } else if CommandLine.arguments.contains("-vibratoSelfTest") {
                    VibratoSelfTestView()
                } else if CommandLine.arguments.contains("-tunerPreview") {
                    NavigationStack { TunerView() }
                } else if CommandLine.arguments.contains("-rhythmPreview") {
                    NavigationStack { RhythmPracticeView() }
                } else if CommandLine.arguments.contains("-bowPreview") {
                    NavigationStack { BowPracticeView() }
                } else if CommandLine.arguments.contains("-vibratoPreview") || CommandLine.arguments.contains("-vibratoNoInstrument") || CommandLine.arguments.contains("-vibratoPractice") {
                    NavigationStack {
                        VibratoPracticeView()
                    }
                } else if CommandLine.arguments.contains("-studioPreview") {
                    NavigationStack { PracticeStudioView() }
                } else if CommandLine.arguments.contains("-pdfViewerPreview") {
                    let sample = PDFPreviewFactory.makeSample()
                    NavigationStack {
                        PDFScoreViewer(score: sample.score, fileURL: sample.url)
                    }
                } else {
                    ContentView()
                }
                #else
                ContentView()
                #endif
            }
            .environmentObject(history)
            .environmentObject(proStore)
        }
    }
}

#if DEBUG
/// 仅用于模拟器截图验证：现场生成一份两页 PDF，避免把示例文件打进 App。
private enum PDFPreviewFactory {
    static func makeSample() -> (score: PDFScore, url: URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dorewio-preview-score.pdf")
        let pageSize = CGSize(width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let ink = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
        let accent = UIColor(red: 0.78, green: 0.16, blue: 0.12, alpha: 1)

        try? renderer.writePDF(to: url) { context in
            for pageNumber in 1...2 {
                context.beginPage()

                let title = NSAttributedString(
                    string: "dorewio.  ·  预览乐谱",
                    attributes: [.font: UIFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: ink]
                )
                title.draw(at: CGPoint(x: 56, y: 64))

                let subtitle = NSAttributedString(
                    string: "PDF 谱架 · 第 \(pageNumber) / 2 页",
                    attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: accent]
                )
                subtitle.draw(at: CGPoint(x: 56, y: 100))

                for system in 0..<4 {
                    let top = CGFloat(190 + system * 120)
                    let staff = UIBezierPath()
                    for line in 0..<5 {
                        let y = top + CGFloat(line) * 10
                        staff.move(to: CGPoint(x: 56, y: y))
                        staff.addLine(to: CGPoint(x: pageSize.width - 56, y: y))
                    }
                    ink.setStroke()
                    staff.lineWidth = 0.8
                    staff.stroke()

                    let clef = NSAttributedString(
                        string: "𝄞",
                        attributes: [.font: UIFont.systemFont(ofSize: 34), .foregroundColor: ink]
                    )
                    clef.draw(at: CGPoint(x: 64, y: top - 18))
                }

                let footer = NSAttributedString(
                    string: "Offline preview — stored on device",
                    attributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.secondaryLabel]
                )
                footer.draw(at: CGPoint(x: 56, y: pageSize.height - 60))
            }
        }

        let score = PDFScore(
            id: UUID(),
            displayName: "预览乐谱",
            fileName: url.lastPathComponent,
            pageCount: 2,
            importedAt: .now
        )
        return (score, url)
    }
}
#endif
