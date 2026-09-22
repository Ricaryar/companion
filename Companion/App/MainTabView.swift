import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var store = ConsultationStore.shared
    @State private var deepLink = ConsultationDeepLink.shared
    @State private var ratingTargetId: String?
    @State private var showRating = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)

            PublicQALibraryView()
                .tabItem { Label("提问", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(store.unreadCount > 0 ? store.unreadCount : 0)
                .tag(1)

            CalendarHistoryView()
                .tabItem { Label("日历", systemImage: "calendar") }
                .tag(2)

            TrendsTabView()
                .tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }
                .tag(3)

            SettingsTabView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(AppTheme.brandTeal)
        .onAppear {
            presentRatingIfNeeded()
            handleDeepLinkIfNeeded()
        }
        .onChange(of: selectedTab) { _, _ in
            store.processTimeouts()
            presentRatingIfNeeded()
        }
        .onChange(of: deepLink.shouldSelectAskTab) { _, need in
            if need {
                selectedTab = 1
                deepLink.shouldSelectAskTab = false
            }
        }
        .onChange(of: deepLink.shouldSelectMoreTab) { _, need in
            if need, !AccountStore.shared.isDoctorSession {
                selectedTab = 4
                deepLink.shouldSelectMoreTab = false
            }
        }
        .onChange(of: deepLink.pendingChatId) { _, _ in
            handleDeepLinkIfNeeded()
        }
        .sheet(isPresented: $showRating) {
            if let id = ratingTargetId {
                ConsultationRatingSheet(consultationId: id) {
                    showRating = false
                    ratingTargetId = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        presentRatingIfNeeded()
                    }
                }
            }
        }
    }

    private func handleDeepLinkIfNeeded() {
        if deepLink.shouldSelectAskTab {
            selectedTab = 1
            deepLink.shouldSelectAskTab = false
        }
        if deepLink.shouldSelectMoreTab {
            selectedTab = 4
            deepLink.shouldSelectMoreTab = false
        }
    }

    private func presentRatingIfNeeded() {
        store.processTimeouts()
        guard !showRating, let pending = store.pendingRatingConsultation else { return }
        ratingTargetId = pending.id
        showRating = true
    }
}

#Preview {
    MainTabView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
