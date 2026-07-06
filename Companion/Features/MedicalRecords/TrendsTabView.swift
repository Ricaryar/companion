import SwiftUI

/// 底部 Tab「趋势」根视图
struct TrendsTabView: View {
    var body: some View {
        NavigationStack {
            LabTrendsView()
        }
    }
}

#Preview {
    TrendsTabView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
