import SwiftUI

@main
struct DorewioApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                PracticeView()
                    .tabItem {
                        Label("练习", systemImage: "house")
                    }

                ScorePracticeView()
                    .tabItem {
                        Label("乐谱", systemImage: "music.note.list")
                    }
            }
            .tint(Color(red: 0.74, green: 0.24, blue: 0.20))
            .preferredColorScheme(.light)
        }
    }
}
