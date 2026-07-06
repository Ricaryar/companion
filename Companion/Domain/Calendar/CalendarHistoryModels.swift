import Foundation

enum CalendarMilestoneKind: String {
    case regimenStart
    case regimenEnd
}

struct CalendarMilestone: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let kind: CalendarMilestoneKind
}

struct CalendarDaySummary: Identifiable {
    var id: Date { date }
    let date: Date
    let checkIn: SymptomLog?
    let events: [ScheduleEvent]
    let milestones: [CalendarMilestone]

    var hasCheckIn: Bool { checkIn != nil }
    var completedEventCount: Int { events.filter { $0.status == .done }.count }
    var relevantEventCount: Int { events.filter { $0.status != .skipped }.count }

    /// 0 无 · 1 有安排 · 2 有完成或打卡 · 3 打卡+完成
    var activityLevel: Int {
        let score = (hasCheckIn ? 2 : 0) + min(completedEventCount, 2) + (relevantEventCount > 0 && completedEventCount == 0 ? 1 : 0)
        return min(3, score)
    }

    var hasActivity: Bool {
        hasCheckIn || !events.isEmpty || !milestones.isEmpty
    }
}

struct TreatmentAchievements {
    let checkInDays: Int
    let completedTasks: Int
    let currentStreak: Int
    let longestStreak: Int
    let regimenPhases: Int
    let journeyDays: Int
}

struct CalendarMonthData {
    let monthStart: Date
    let days: [Date]
    let summariesByDay: [Date: CalendarDaySummary]
    let achievements: TreatmentAchievements
}
