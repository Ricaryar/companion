import Foundation

enum CalendarHistoryAggregator {
    static func monthData(
        for month: Date,
        events: [ScheduleEvent],
        checkIns: [SymptomLog],
        regimens: [RegimenInstance],
        calendar: Calendar = .current
    ) -> CalendarMonthData {
        let monthStart = startOfMonth(month, calendar: calendar)
        let days = daysInMonth(monthStart, calendar: calendar)
        let summaries = buildSummaries(
            from: days.first ?? monthStart,
            to: days.last ?? monthStart,
            events: events,
            checkIns: checkIns,
            regimens: regimens,
            calendar: calendar
        )
        let achievements = computeAchievements(
            events: events,
            checkIns: checkIns,
            regimens: regimens,
            calendar: calendar
        )
        return CalendarMonthData(
            monthStart: monthStart,
            days: days,
            summariesByDay: summaries,
            achievements: achievements
        )
    }

    static func summary(
        for day: Date,
        events: [ScheduleEvent],
        checkIns: [SymptomLog],
        regimens: [RegimenInstance],
        calendar: Calendar = .current
    ) -> CalendarDaySummary {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        let dayEvents = events.filter { $0.plannedAt >= start && $0.plannedAt < end }
            .sorted { $0.plannedAt < $1.plannedAt }

        let checkIn = checkIns.first { calendar.isDate($0.date, inSameDayAs: start) }

        var milestones: [CalendarMilestone] = []
        for regimen in regimens {
            if calendar.isDate(regimen.startDate, inSameDayAs: start) {
                milestones.append(CalendarMilestone(
                    date: start,
                    title: "开始 \(regimen.displayName)",
                    kind: .regimenStart
                ))
            }
            if let ended = regimen.endedAt, calendar.isDate(ended, inSameDayAs: start) {
                milestones.append(CalendarMilestone(
                    date: start,
                    title: "结束 \(regimen.displayName)",
                    kind: .regimenEnd
                ))
            }
        }

        return CalendarDaySummary(
            date: start,
            checkIn: checkIn,
            events: dayEvents,
            milestones: milestones
        )
    }

    // MARK: - Private

    private static func buildSummaries(
        from start: Date,
        to end: Date,
        events: [ScheduleEvent],
        checkIns: [SymptomLog],
        regimens: [RegimenInstance],
        calendar: Calendar
    ) -> [Date: CalendarDaySummary] {
        var result: [Date: CalendarDaySummary] = [:]
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while cursor <= last {
            result[cursor] = summary(for: cursor, events: events, checkIns: checkIns, regimens: regimens, calendar: calendar)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
        }
        return result
    }

    private static func computeAchievements(
        events: [ScheduleEvent],
        checkIns: [SymptomLog],
        regimens: [RegimenInstance],
        calendar: Calendar
    ) -> TreatmentAchievements {
        let checkInDays = Set(checkIns.map { calendar.startOfDay(for: $0.date) }).count
        let completedTasks = events.filter { $0.status == .done }.count
        let streaks = checkInStreaks(from: checkIns, calendar: calendar)
        let regimenPhases = regimens.count

        let journeyStart = [
            regimens.map(\.startDate).min(),
            checkIns.map(\.date).min()
        ].compactMap { $0 }.min() ?? Date.now

        let daySpan = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: journeyStart),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0
        let journeyDays = max(1, daySpan + 1)

        return TreatmentAchievements(
            checkInDays: checkInDays,
            completedTasks: completedTasks,
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            regimenPhases: regimenPhases,
            journeyDays: journeyDays
        )
    }

    private static func checkInStreaks(from logs: [SymptomLog], calendar: Calendar) -> (current: Int, longest: Int) {
        let days = Set(logs.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return (0, 0) }

        var longest = 1
        var run = 1
        for i in 1..<days.count {
            let gap = calendar.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 2
            if gap == 1 {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }

        var current = 0
        var cursor = calendar.startOfDay(for: .now)
        while days.contains(cursor) {
            current += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        return (current, longest)
    }

    private static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static func daysInMonth(_ monthStart: Date, calendar: Calendar) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart),
              let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { return [] }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
    }
}
