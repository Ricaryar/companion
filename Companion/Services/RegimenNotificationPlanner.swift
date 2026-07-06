import Foundation
import SwiftData
import UserNotifications

enum RegimenNotificationPlanner {
    private static let checkInNotificationID = "daily-check-in"

    static func rescheduleAll(
        events: [ScheduleEvent],
        settings: AppSettings = .shared
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let regimenIDs = pending.map(\.identifier).filter { $0 != checkInNotificationID && !$0.hasPrefix("checkin-") }
        center.removePendingNotificationRequests(withIdentifiers: regimenIDs)

        let now = Date()
        let future = events.filter { event in
            guard event.status == .pending || event.status == .deferred else { return false }
            guard let regimen = event.regimen, regimen.isActive else { return false }
            return event.plannedAt > now
        }

        let allGroups = Dictionary(grouping: future, by: \.minuteBucket)
        for (_, items) in allGroups {
            let sorted = items.sorted { $0.plannedAt < $1.plannedAt }
            guard let first = sorted.first else { continue }

            if settings.mergeReminders {
                let group = TodayTaskGroup(id: first.minuteBucket, plannedAt: first.plannedAt, events: sorted)
                await NotificationScheduler.scheduleMergedReminder(for: group)
            } else {
                for event in sorted {
                    let id = event.notificationID ?? "evt-\(UUID().uuidString)"
                    event.notificationID = id
                    await NotificationScheduler.scheduleNotification(
                        id: id,
                        title: event.title,
                        body: oralBody(for: event),
                        at: event.plannedAt
                    )
                }
            }

            for event in sorted {
                await scheduleSupplementalReminders(for: event)
            }
        }

        await scheduleCheckInReminder(settings: settings)
    }

    static func cancelAllRegimenNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0 != checkInNotificationID }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Private

    private static func notificationBody(for group: TodayTaskGroup) -> String {
        if group.events.count == 1, let event = group.events.first {
            return oralBody(for: event)
        }
        return group.events.map(\.title).joined(separator: "、")
    }

    private static func oralBody(for event: ScheduleEvent) -> String {
        if event.eventType == .oral, let meal = event.mealTiming {
            return "\(event.title) · \(meal.reminderSuffix)"
        }
        return event.title
    }

    private static func scheduleSupplementalReminders(for event: ScheduleEvent) async {
        guard [.infusion, .lab, .imaging, .visit].contains(event.eventType) else { return }
        let cal = Calendar.current
        let day = cal.startOfDay(for: event.plannedAt)

        if let eve = cal.date(bySettingHour: 20, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -1, to: day) ?? day),
           eve > .now {
            await NotificationScheduler.scheduleNotification(
                id: "eve-\(event.notificationID ?? event.minuteBucket)",
                title: "明日安排提醒",
                body: "明天有：\(event.title)",
                at: eve
            )
        }

        if let morning = cal.date(bySettingHour: 8, minute: 0, second: 0, of: day),
           morning > .now, morning < event.plannedAt {
            await NotificationScheduler.scheduleNotification(
                id: "am-\(event.notificationID ?? event.minuteBucket)",
                title: CopyStrings.todayTasks,
                body: "今日：\(event.title)",
                at: morning
            )
        }
    }

    private static func scheduleCheckInReminder(settings: AppSettings) async {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.hour = settings.checkInPreference.defaultHour
        comps.minute = settings.checkInPreference.defaultMinute

        let content = UNMutableNotificationContent()
        content.title = CopyStrings.checkIn
        content.body = "记录今日体温与症状，我们会陪你一起看变化。"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: checkInNotificationID, content: content, trigger: trigger)
        )
    }
}
