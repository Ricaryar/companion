import Foundation

enum HistoryShareBuilder {
    static func build(
        achievements: TreatmentAchievements,
        month: Date,
        selectedDay: Date?,
        summariesByDay: [Date: CalendarDaySummary],
        activeRegimenName: String?,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .long
        formatter.timeStyle = .none

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "zh_CN")
        monthFormatter.dateFormat = "yyyy年M月"

        var lines: [String] = []
        lines.append("【伴行 · 治疗足迹】")
        lines.append("")
        lines.append("陪伴记录，仅供个人回顾与就诊沟通参考。")
        lines.append("")

        if let name = activeRegimenName {
            lines.append("当前方案：\(name)")
        }
        lines.append("同行 \(achievements.journeyDays) 天 · 打卡 \(achievements.checkInDays) 天 · 完成事项 \(achievements.completedTasks) 项")
        if achievements.currentStreak > 0 {
            lines.append("连续打卡 \(achievements.currentStreak) 天（最长 \(achievements.longestStreak) 天）")
        }
        lines.append("经历 \(achievements.regimenPhases) 个治疗阶段")
        lines.append("")

        if let selectedDay, let summary = summariesByDay[calendar.startOfDay(for: selectedDay)] {
            lines.append("── \(formatter.string(from: selectedDay)) ──")
            appendDaySummary(summary, to: &lines)
            lines.append("")
        }

        lines.append("── \(monthFormatter.string(from: month)) 概览 ──")
        let monthDays = summariesByDay.keys.sorted().filter { day in
            calendar.isDate(day, equalTo: month, toGranularity: .month) && (summariesByDay[day]?.hasActivity == true)
        }
        if monthDays.isEmpty {
            lines.append("本月暂无记录")
        } else {
            for day in monthDays {
                guard let summary = summariesByDay[day], summary.hasActivity else { continue }
                let short = shortDayFormatter.string(from: day)
                var parts: [String] = []
                if summary.hasCheckIn { parts.append("打卡") }
                if summary.completedEventCount > 0 { parts.append("完成\(summary.completedEventCount)项") }
                if !summary.milestones.isEmpty { parts.append(summary.milestones.first!.title) }
                let pending = summary.events.filter { $0.status == .pending || $0.status == .deferred }.count
                if pending > 0 { parts.append("计划\(pending)项") }
                lines.append("\(short)：\(parts.joined(separator: " · "))")
            }
        }

        lines.append("")
        lines.append("—— 来自伴行 App ——")
        lines.append(CopyStrings.disclaimerGlobal)
        return lines.joined(separator: "\n")
    }

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    private static func appendDaySummary(_ summary: CalendarDaySummary, to lines: inout [String]) {
        for milestone in summary.milestones {
            lines.append("★ \(milestone.title)")
        }
        if let log = summary.checkIn {
            lines.append("✓ 症状打卡 · \(log.riskLevel.displayName)")
        }
        for event in summary.events {
            let mark: String
            switch event.status {
            case .done: mark = "✓"
            case .skipped: mark = "—"
            case .deferred: mark = "↷"
            case .pending: mark = "○"
            }
            let time = event.plannedAt.formatted(date: .omitted, time: .shortened)
            lines.append("\(mark) \(time) \(event.title)")
        }
    }
}
