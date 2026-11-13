import SwiftUI

@main
struct DorewioApp: App {
    @StateObject private var history = PracticeHistoryStore()
    @StateObject private var proStore = ProStore()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if CommandLine.arguments.contains("-paywallPreview") {
                    NavigationStack {
                        PaywallView()
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
