import SwiftUI
import SwiftData

struct RootView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var accountStore = AccountStore.shared

    var body: some View {
        Group {
            if !accountStore.isLoggedIn {
                AuthContainerView()
            } else if accountStore.isDoctorSession {
                DoctorMainView()
            } else if settings.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(AppTheme.brandTeal)
        .onAppear { _ = accountStore.changeToken }
    }
}

#Preview {
    RootView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
