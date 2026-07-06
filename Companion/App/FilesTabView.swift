import SwiftUI

/// 底部 Tab「文件」：就医准备 + 全部报告与附件
struct FilesTabView: View {
    var body: some View {
        NavigationStack {
            DocumentsLibraryView(
                navigationTitle: "文件",
                showMedicalShortcuts: true
            )
        }
    }
}

#Preview {
    FilesTabView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
