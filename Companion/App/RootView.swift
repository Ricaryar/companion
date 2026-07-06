import SwiftUI
import SwiftData

struct RootView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(AppTheme.brandTeal)
    }
}

#Preview {
    RootView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
