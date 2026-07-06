import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)

            CalendarHistoryView()
                .tabItem { Label("日历", systemImage: "calendar") }
                .tag(1)

            TrendsTabView()
                .tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }
                .tag(2)

            FilesTabView()
                .tabItem { Label("文件", systemImage: "folder.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(AppTheme.brandTeal)
    }
}

#Preview {
    MainTabView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
