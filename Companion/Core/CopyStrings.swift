import Foundation

enum CopyStrings {
    static let appNameZH = "伴行"
    static let appNameEN = "Companion"
    static let tagline = "结直肠治疗与随访助手"

    static let disclaimerGlobal =
        "伴行会帮你记录与提醒，但医疗决策应以医生意见为准。如有明显不适或紧急情况，请尽快联系医生或前往急诊。"
    static let disclaimerSideEffects =
        "以下为一般性健康教育信息，不能替代您的个体化医嘱。请勿自行调整用药。"
    static let disclaimerRegimen =
        "日程由你按医嘱自行设置，请以门诊医嘱为准。"
    static let regimenLineHint = "线数仅作记录，不影响可选方案。"

    static let riskGreen =
        "今天的数据整体平稳，辛苦了。继续按时休息和补水，我们会在关键时点提醒你。"
    static let riskYellow =
        "这两天有些变化值得留意。请优先补水与清淡饮食，继续观察。如不适加重或出现头晕少尿，请联系医生。"
    static let riskRed =
        "今天的体温/症状提示需要尽快联系医生。要不要我先把近7天的摘要整理好给你带上？"

    static let onboardingTitle = "欢迎使用伴行"
    static let onboardingSubtitle = "我们会陪你记录治疗与随访，日程请以医生医嘱为准。"
    static let onboardingCheckInMorning = "早晨打卡（09:00）"
    static let onboardingCheckInEvening = "晚间打卡（20:30）"

    static let emptyRegimen = "尚未添加治疗方案"
    static let addRegimen = "添加方案"
    static let combinationModeTitle = "组合用药"
    static let combinationModeHint = "后线方案个体差异大：可选一个主方案，并加用一种或多种药物（以门诊医嘱为准）。"
    static let primaryRegimenSection = "主方案（必选）"
    static let addonRegimenSection = "加用药物（可选，可多选）"
    static let todayTasks = "今日事项"
    static let checkIn = "今日打卡"
    static let recentReports = "最近报告"
    static let addReport = "添加报告"
    static let treatmentCalendar = "治疗日历"
    static let treatmentCalendarHint = "回顾打卡与治疗日程，记录你的坚持"
}
