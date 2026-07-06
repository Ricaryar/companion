import Foundation
import SwiftData

enum RegimenLifecycle {
    /// 结束方案：标记为非活跃，并取消该方案下所有未完成的日程
    static func endRegimen(_ regimen: RegimenInstance, context: ModelContext) {
        regimen.isActive = false
        regimen.endedAt = .now
        cancelPendingEvents(for: regimen)
        try? context.save()
        RegimenNotificationPlanner.cancelAllRegimenNotifications()
    }

    /// 删除方案（历史方案滑动删除）；关联日程级联删除
    static func deleteRegimen(_ regimen: RegimenInstance, context: ModelContext) {
        for event in regimen.events {
            if let id = event.notificationID {
                NotificationScheduler.cancelNotification(id: id)
            }
        }
        context.delete(regimen)
        try? context.save()
    }

    private static func cancelPendingEvents(for regimen: RegimenInstance) {
        for event in regimen.events {
            guard event.status == .pending || event.status == .deferred else { continue }
            event.status = .skipped
            if let id = event.notificationID {
                NotificationScheduler.cancelNotification(id: id)
            }
        }
    }
}
