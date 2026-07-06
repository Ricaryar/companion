import Foundation
import SwiftData

@Model
final class ScheduleEvent {
    var eventTypeRaw: String
    var title: String
    var plannedAt: Date
    var statusRaw: String
    var mealTimingRaw: String?
    var cycleIndex: Int
    var dayInCycle: Int
    var deferredTo: Date?
    var completedAt: Date?
    var notificationID: String?

    var regimen: RegimenInstance?

    var eventType: ScheduleEventType {
        get { ScheduleEventType(rawValue: eventTypeRaw) ?? .oral }
        set { eventTypeRaw = newValue.rawValue }
    }

    var status: ScheduleEventStatus {
        get { ScheduleEventStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var mealTiming: MealTiming? {
        get { mealTimingRaw.flatMap { MealTiming(rawValue: $0) } }
        set { mealTimingRaw = newValue?.rawValue }
    }

    var minuteBucket: String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: plannedAt)
        return String(format: "%04d%02d%02d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }

    init(
        eventType: ScheduleEventType,
        title: String,
        plannedAt: Date,
        status: ScheduleEventStatus = .pending,
        mealTiming: MealTiming? = nil,
        cycleIndex: Int = 1,
        dayInCycle: Int = 1,
        deferredTo: Date? = nil,
        completedAt: Date? = nil,
        notificationID: String? = nil,
        regimen: RegimenInstance? = nil
    ) {
        self.eventTypeRaw = eventType.rawValue
        self.title = title
        self.plannedAt = plannedAt
        self.statusRaw = status.rawValue
        self.mealTimingRaw = mealTiming?.rawValue
        self.cycleIndex = cycleIndex
        self.dayInCycle = dayInCycle
        self.deferredTo = deferredTo
        self.completedAt = completedAt
        self.notificationID = notificationID
        self.regimen = regimen
    }
}
