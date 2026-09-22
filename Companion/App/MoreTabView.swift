import SwiftUI

/// 底部 Tab「更多」：文件、设置（普通用户，不含医生端入口）
struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    DocumentsLibraryView(
                        navigationTitle: "文件",
                        showMedicalShortcuts: true
                    )
                } label: {
                    Label("文件", systemImage: "folder.fill")
                }

                NavigationLink {
                    MedicationShareCommunityView()
                } label: {
                    Label("真实用药", systemImage: "pills.fill")
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("设置", systemImage: "gearshape.fill")
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
