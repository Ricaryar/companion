import SwiftUI

/// 底部 Tab「设置」
struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            SettingsView()
        }
    }
}

#Preview {
    SettingsTabView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
