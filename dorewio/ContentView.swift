import SwiftUI

struct ContentView: View {
    @State private var selection = Self.initialTab

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tag(0)
                .tabItem {
                    Label("今天", systemImage: "house.fill")
                }

            LearningLibraryView()
                .tag(1)
                .tabItem {
                    Label("学习", systemImage: "book.closed.fill")
                }

            PracticeLibraryView()
                .tag(2)
                .tabItem {
                    Label("训练", systemImage: "metronome.fill")
                }

            NavigationStack {
                ProGate {
                    PracticeStudioView()
                }
            }
                .tag(3)
                .tabItem {
                    Label("曲目", systemImage: "music.note.list")
                }

            PracticeProgressView()
                .tag(4)
                .tabItem {
                    Label("进度", systemImage: "chart.bar.fill")
                }
        }
        .tint(PracticePalette.accent)
        .modifier(IPadNavigationStyle())
    }

    /// 模拟器截图用：`-tab 3` 直接打开「曲目」。
    private static var initialTab: Int {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "-tab"),
           index + 1 < arguments.count,
           let tab = Int(arguments[index + 1]) {
            return min(max(tab, 0), 4)
        }
        #endif
        return 0
    }
}

/// iPad 常规宽度下使用可转换侧边栏；iPhone / 分屏紧凑宽度回退为顶部标签栏。
private struct IPadNavigationStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), horizontalSizeClass == .regular {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content
        }
    }
}
