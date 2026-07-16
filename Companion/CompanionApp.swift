import SwiftUI
import SwiftData
import UserNotifications

@main
struct CompanionApp: App {
    let modelContainer = CompanionModelContainer.make()

    init() {
        let center = UNUserNotificationCenter.current()
        center.delegate = AppNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    _ = await NotificationScheduler.requestAuthorizationIfNeeded()
                }
        }
        .modelContainer(modelContainer)
    }
}
