import Foundation
import SwiftData

/// 组合方案中每一种药的个性化口服设置
struct DrugOralScheduleDraft: Identifiable {
    let id: String
    var displayName: String
    var useCustomOral: Bool
    var config: CustomOralScheduleConfig

    init(code: String, displayName: String, regimen: RegimenDef?) {
        self.id = code
        self.displayName = displayName
        self.useCustomOral = true
        self.config = CustomOralScheduleBuilder.suggestedConfig(for: regimen)
        self.config.drugName = displayName
    }
}

/// 患者按医嘱自定义的「连吃 X 天、停 Y 天」口服周期（如 TAS-102 55mg）
struct CustomOralScheduleConfig {
    var drugName: String
    var doseText: String
    var daysOn: Int
    var daysOff: Int
    var repeatCycles: Int
    var includeMorningDose: Bool
    var includeEveningDose: Bool
    var morningHour: Int
    var morningMinute: Int
    var eveningHour: Int
    var eveningMinute: Int
    var mealTiming: MealTiming
}

enum CustomOralScheduleBuilder {
    static func generate(
        config: CustomOralScheduleConfig,
        regimenCode: String,
        displayName: String,
        line: TreatmentLineKind,
        startDate: Date,
        settings: AppSettings = .shared
    ) -> (instance: RegimenInstance, events: [ScheduleEvent]) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let cycleLength = max(1, config.daysOn + config.daysOff)
        let doseSuffix = config.doseText.trimmingCharacters(in: .whitespaces).isEmpty
            ? ""
            : " \(config.doseText.trimmingCharacters(in: .whitespaces))"

        let instance = RegimenInstance(
            regimenCode: regimenCode,
            displayName: displayName,
            line: line,
            isMaintenance: line == .maintenance,
            startDate: start,
            cycleDays: cycleLength
        )

        var events: [ScheduleEvent] = []

        for cycle in 1...max(1, config.repeatCycles) {
            let cycleStartOffset = (cycle - 1) * cycleLength
            for dayInOnPeriod in 0..<max(1, config.daysOn) {
                let dayOffset = cycleStartOffset + dayInOnPeriod
                guard let day = cal.date(byAdding: .day, value: dayOffset, to: start) else { continue }
                let dayInCycle = dayInOnPeriod + 1

                if config.includeMorningDose {
                    let planned = combine(
                        date: day,
                        hour: config.morningHour,
                        minute: config.morningMinute,
                        calendar: cal
                    )
                    events.append(makeEvent(
                        title: "\(config.drugName) 早\(doseSuffix)",
                        plannedAt: planned,
                        mealTiming: config.mealTiming,
                        cycleIndex: cycle,
                        dayInCycle: dayInCycle,
                        regimen: instance
                    ))
                }

                if config.includeEveningDose {
                    let planned = combine(
                        date: day,
                        hour: config.eveningHour,
                        minute: config.eveningMinute,
                        calendar: cal
                    )
                    events.append(makeEvent(
                        title: "\(config.drugName) 晚\(doseSuffix)",
                        plannedAt: planned,
                        mealTiming: config.mealTiming,
                        cycleIndex: cycle,
                        dayInCycle: dayInCycle,
                        regimen: instance
                    ))
                }
            }
        }

        instance.events = events
        return (instance, events)
    }

    /// 仅生成口服事件，合并到同一方案实例（多药联用）
    static func generateOralEvents(
        config: CustomOralScheduleConfig,
        startDate: Date,
        regimen: RegimenInstance
    ) -> [ScheduleEvent] {
        generate(
            config: config,
            regimenCode: regimen.regimenCode,
            displayName: regimen.displayName,
            line: regimen.line,
            startDate: startDate
        ).events.map { event in
            event.regimen = regimen
            return event
        }
    }

    private static func makeEvent(
        title: String,
        plannedAt: Date,
        mealTiming: MealTiming,
        cycleIndex: Int,
        dayInCycle: Int,
        regimen: RegimenInstance
    ) -> ScheduleEvent {
        ScheduleEvent(
            eventType: .oral,
            title: title,
            plannedAt: plannedAt,
            mealTiming: mealTiming,
            cycleIndex: cycleIndex,
            dayInCycle: dayInCycle,
            notificationID: "evt-\(UUID().uuidString)",
            regimen: regimen
        )
    }

    private static func combine(date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps) ?? date
    }

    /// 选中模板后给出可编辑的默认口服配置
    static func suggestedConfig(for regimen: RegimenDef?, settings: AppSettings = .shared) -> CustomOralScheduleConfig {
        let morning = settings.oralMorningTime
        let evening = settings.oralEveningTime
        var config = CustomOralScheduleConfig(
            drugName: regimen?.displayName ?? "口服药",
            doseText: "",
            daysOn: 5,
            daysOff: 7,
            repeatCycles: 6,
            includeMorningDose: true,
            includeEveningDose: true,
            morningHour: morning.hour,
            morningMinute: morning.minute,
            eveningHour: evening.hour,
            eveningMinute: evening.minute,
            mealTiming: .after
        )

        guard let regimen else { return config }

        if regimen.code == "TAS102" {
            config.drugName = "TAS-102"
            config.daysOn = 5
            config.daysOff = 7
        } else if regimen.code == "FRUQUINTINIB" {
            config.drugName = "呋喹替尼"
            config.daysOn = 21
            config.daysOff = 7
            config.includeEveningDose = false
        } else if regimen.code == "REGORAFENIB" {
            config.drugName = "瑞戈非尼"
            config.daysOn = 21
            config.daysOff = 7
        } else if regimen.cycleDays == 14 {
            config.daysOn = 14
            config.daysOff = 7
        } else if regimen.cycleDays >= 28 {
            config.daysOn = 5
            config.daysOff = 23
        }

        return config
    }
}

/// 患者手动添加的单次日程
struct ManualScheduleDraft: Identifiable {
    let id = UUID()
    var date: Date
    var eventType: ScheduleEventType
    var title: String
}

extension ScheduleGenerator {
    func appendManualEvents(
        _ drafts: [ManualScheduleDraft],
        to instance: RegimenInstance,
        startingEvents: [ScheduleEvent]
    ) -> [ScheduleEvent] {
        var events = startingEvents
        for draft in drafts {
            let title = draft.title.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            events.append(
                ScheduleEvent(
                    eventType: draft.eventType,
                    title: title,
                    plannedAt: draft.date,
                    mealTiming: draft.eventType == .oral ? .after : nil,
                    cycleIndex: 1,
                    dayInCycle: 1,
                    notificationID: "evt-\(UUID().uuidString)",
                    regimen: instance
                )
            )
        }
        events.sort { $0.plannedAt < $1.plannedAt }
        instance.events = events
        return events
    }
}
