import Foundation

enum TodayCheckInShareBuilder {
    static func build(log: SymptomLog?) -> String {
        let dateText = Date.now.formatted(date: .abbreviated, time: .omitted)
        var lines: [String] = []
        lines.append("【伴行 · 今日打卡】")
        lines.append(dateText)
        lines.append("")

        if let log {
            lines.append("今天已完成症状打卡 ✓")
            lines.append("疼痛 \(log.pain)/10")
            if let fever = log.fever {
                lines.append(String(format: "体温 %.1f℃", fever))
            }
            lines.append("排便 \(log.stoolCount) 次 · 布里斯托 \(log.bristolType)")
            if log.hasBleeding {
                lines.append("有便血/黑便记录，请及时就医评估")
            }
            lines.append("状态：\(log.riskLevel.displayName)")
        } else {
            lines.append("今天坚持用伴行记录健康点滴。")
            lines.append("完成打卡，更好地陪伴治疗与随访。")
        }

        lines.append("")
        lines.append("—— 来自伴行 App ——")
        return lines.joined(separator: "\n")
    }
}
