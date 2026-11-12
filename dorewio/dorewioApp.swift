import SwiftUI

@main
struct DorewioApp: App {
    @StateObject private var history = PracticeHistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(history)
        }
    }
}
