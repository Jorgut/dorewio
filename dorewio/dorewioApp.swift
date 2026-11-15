import SwiftUI

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
