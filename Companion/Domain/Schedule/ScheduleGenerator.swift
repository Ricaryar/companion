import Foundation
import SwiftData

struct ScheduleGenerator {
    let settings: AppSettings

    init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    func generate(
        regimen: RegimenDef,
        line: TreatmentLineKind,
        startDate: Date,
        cycles: Int = 6
    ) -> (instance: RegimenInstance, events: [ScheduleEvent]) {
        let instance = RegimenInstance(
            regimenCode: regimen.code,
            displayName: regimen.displayName,
            line: line,
            isMaintenance: line == .maintenance,
            startDate: Calendar.current.startOfDay(for: startDate),
            cycleDays: regimen.cycleDays
        )

        var events: [ScheduleEvent] = []
        let cal = Calendar.current

        for cycle in 1...cycles {
            let cycleStart = cal.date(
                byAdding: .day,
                value: (cycle - 1) * regimen.cycleDays,
                to: instance.startDate
            ) ?? instance.startDate

            for template in regimen.events where template.repeatEveryCycle {
                guard let eventType = ScheduleEventType(rawValue: template.type) else { continue }
                let day = cal.date(byAdding: .day, value: template.dayOffset, to: cycleStart) ?? cycleStart
                let planned = combine(
                    date: day,
                    hour: oralHour(for: eventType, template: template),
                    minute: oralMinute(for: eventType, template: template)
                )
                let meal = template.mealTiming.flatMap { MealTiming(rawValue: $0) }
                let dayInCycle = max(1, template.dayOffset + 1)

                events.append(
                    makeEvent(
                        eventType: eventType,
                        title: template.title,
                        plannedAt: planned,
                        mealTiming: meal,
                        cycleIndex: cycle,
                        dayInCycle: dayInCycle,
                        regimen: instance
                    )
                )
            }

            for checkup in regimen.checkups {
                let eventType: ScheduleEventType = checkup.type == "visit" ? .visit : (checkup.type == "imaging" ? .imaging : .lab)
                let day = cal.date(byAdding: .day, value: checkup.dayOffset, to: cycleStart) ?? cycleStart
                let planned = combine(date: day, hour: checkup.hour, minute: checkup.minute)

                events.append(
                    makeEvent(
                        eventType: eventType,
                        title: checkup.title,
                        plannedAt: planned,
                        cycleIndex: cycle,
                        dayInCycle: max(1, checkup.dayOffset + 1),
                        regimen: instance
                    )
                )

                if eventType == .infusion || eventType == .lab || eventType == .imaging || eventType == .visit {
                    scheduleReminderOffsets(for: planned, title: checkup.title, into: &events, cycleIndex: cycle, dayInCycle: checkup.dayOffset + 1, instance: instance, baseType: eventType)
                }
            }
        }

        instance.events = events
        return (instance, events)
    }

    /// 主方案 + 多加用（后线/个体化）；日程合并到同一治疗实例
    func generateCombined(
        primary: RegimenDef,
        addons: [RegimenDef],
        line: TreatmentLineKind,
        startDate: Date,
        cycles: Int = 6
    ) -> (instance: RegimenInstance, events: [ScheduleEvent]) {
        var result = generate(regimen: primary, line: line, startDate: startDate, cycles: cycles)
        let instance = result.instance

        if addons.isEmpty {
            return result
        }

        var merged = result.events
        for addon in addons {
            let addonResult = generate(regimen: addon, line: line, startDate: startDate, cycles: cycles)
            let relabeled = addonResult.events.map { event -> ScheduleEvent in
                event.title = "〔\(addon.displayName)〕\(event.title)"
                event.regimen = instance
                return event
            }
            merged.append(contentsOf: relabeled)
        }

        merged.sort { $0.plannedAt < $1.plannedAt }
        instance.events = merged
        instance.regimenCode = ([primary.code] + addons.map(\.code)).joined(separator: "|")
        instance.displayName = ([primary.displayName] + addons.map(\.displayName)).joined(separator: " + ")

        return (instance, merged)
    }

    func shiftCycle(instance: RegimenInstance, by days: Int, fromCycleIndex: Int? = nil) {
        let startCycle = fromCycleIndex ?? instance.currentCycleIndex
        instance.shiftDays += days
        let cal = Calendar.current

        for event in instance.events where event.status == .pending {
            if event.cycleIndex >= startCycle {
                if let shifted = cal.date(byAdding: .day, value: days, to: event.plannedAt) {
                    event.plannedAt = shifted
                }
            }
        }
    }

    func deferEvent(_ event: ScheduleEvent, option: DeferOption) {
        let cal = Calendar.current
        let now = Date()

        switch option {
        case .plusOneHour:
            event.plannedAt = cal.date(byAdding: .hour, value: 1, to: now) ?? now
        case .tonightEight:
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = 20
            comps.minute = 0
            event.plannedAt = cal.date(from: comps) ?? now
        case .tomorrowMorning:
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
            comps.hour = settings.oralMorningTime.hour
            comps.minute = settings.oralMorningTime.minute
            event.plannedAt = cal.date(from: comps) ?? now
        }

        event.status = .deferred
        event.deferredTo = event.plannedAt
    }

    enum DeferOption {
        case plusOneHour
        case tonightEight
        case tomorrowMorning
    }

    // MARK: - Private

    private func makeEvent(
        eventType: ScheduleEventType,
        title: String,
        plannedAt: Date,
        mealTiming: MealTiming? = nil,
        cycleIndex: Int,
        dayInCycle: Int,
        regimen: RegimenInstance
    ) -> ScheduleEvent {
        let event = ScheduleEvent(
            eventType: eventType,
            title: title,
            plannedAt: plannedAt,
            mealTiming: mealTiming,
            cycleIndex: cycleIndex,
            dayInCycle: dayInCycle,
            notificationID: "evt-\(UUID().uuidString)",
            regimen: regimen
        )
        return event
    }

    private func oralHour(for type: ScheduleEventType, template: RegimenEventTemplate) -> Int {
        if type == .oral {
            return template.hour == 8 ? settings.oralMorningTime.hour : settings.oralEveningTime.hour
        }
        return template.hour
    }

    private func oralMinute(for type: ScheduleEventType, template: RegimenEventTemplate) -> Int {
        if type == .oral {
            return template.hour == 8 ? settings.oralMorningTime.minute : settings.oralEveningTime.minute
        }
        return template.minute
    }

    private func combine(date: Date, hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? date
    }

    private func scheduleReminderOffsets(
        for planned: Date,
        title: String,
        into events: inout [ScheduleEvent],
        cycleIndex: Int,
        dayInCycle: Int,
        instance: RegimenInstance,
        baseType: ScheduleEventType
    ) {
        // Placeholder for pre-night / morning reminder events if needed separately
        _ = (planned, title, events, cycleIndex, dayInCycle, instance, baseType)
    }
}

struct TodayTaskGroup: Identifiable {
    let id: String
    let plannedAt: Date
    let events: [ScheduleEvent]
}

extension Array where Element == ScheduleEvent {
    func groupedForToday(merge: Bool, calendar: Calendar = .current) -> [TodayTaskGroup] {
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let today = filter { $0.status == .pending || $0.status == .deferred }
            .filter { $0.plannedAt >= start && $0.plannedAt < end }
            .sorted { $0.plannedAt < $1.plannedAt }

        guard merge else {
            return today.map { TodayTaskGroup(id: $0.persistentModelID.hashValue.description, plannedAt: $0.plannedAt, events: [$0]) }
        }

        let grouped = Dictionary(grouping: today, by: \.minuteBucket)
        return grouped.keys.sorted().compactMap { key in
            guard let items = grouped[key] else { return nil }
            let date = items.first?.plannedAt ?? .now
            return TodayTaskGroup(id: key, plannedAt: date, events: items.sorted { $0.title < $1.title })
        }.sorted { $0.plannedAt < $1.plannedAt }
    }
}
