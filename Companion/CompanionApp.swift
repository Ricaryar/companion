import SwiftUI
import SwiftData

@main
struct CompanionApp: App {
    let modelContainer = CompanionModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
