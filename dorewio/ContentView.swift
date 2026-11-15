import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今天", systemImage: "house.fill")
                }

            LearningLibraryView()
                .tabItem {
                    Label("学习", systemImage: "book.closed.fill")
                }

            PracticeLibraryView()
                .tabItem {
                    Label("训练", systemImage: "metronome.fill")
                }

            NavigationStack {
                ProGate {
                    PracticeStudioView()
                }
            }
                .tabItem {
                    Label("曲目", systemImage: "music.note.list")
                }

            PracticeProgressView()
                .tabItem {
                    Label("进度", systemImage: "chart.bar.fill")
                }
        }
        .tint(PracticePalette.accent)
    }
}
