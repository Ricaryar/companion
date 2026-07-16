import Foundation
import UserNotifications

enum NotificationScheduler {
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        return await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    static func scheduleMergedReminder(for group: TodayTaskGroup) async {
        await scheduleNotification(
            id: "merged-\(group.id)",
            title: CopyStrings.todayTasks,
            body: {
                if group.events.count == 1, let event = group.events.first {
                    if event.eventType == .oral, let meal = event.mealTiming {
                        return "\(event.title) · \(meal.reminderSuffix)"
                    }
                    return event.title
                }
                return group.events.map(\.title).joined(separator: "、")
            }(),
            at: group.plannedAt
        )
    }

    static func scheduleNotification(id: String, title: String, body: String, at date: Date) async {
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }

    /// 立即推送一条本地通知（会出现在通知中心）。
    static func deliverNow(
        id: String,
        title: String,
        body: String,
        userInfo: [AnyHashable: Any] = [:]
    ) async {
        _ = await requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        // 极短延迟，确保可进入通知中心；前台由 delegate 决定是否展示横幅
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }

    static let consultationReplyCategory = "consultation-reply"
    static let consultationIdKey = "consultationId"
    static let notificationTypeKey = "notificationType"
    static let doctorFollowUpType = "doctor-followup"

    static func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    static func cancelNotifications(ids: [String]) {
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// 按前缀批量取消（如 merged-、eve-、am-）
    static func cancelNotifications(matchingPrefix prefix: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }
}
