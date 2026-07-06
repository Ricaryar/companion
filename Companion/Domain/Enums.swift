import Foundation

enum RiskLevel: String, Codable, CaseIterable {
    case green
    case yellow
    case red

    var displayName: String {
        switch self {
        case .green: "平稳"
        case .yellow: "关注"
        case .red: "尽快联系医生"
        }
    }
}

enum ScheduleEventType: String, Codable, CaseIterable {
    case infusion
    case oral
    case lab
    case imaging
    case visit
    case maintenanceSwitch

    var displayName: String {
        switch self {
        case .infusion: "静脉输注"
        case .oral: "口服"
        case .lab: "检验"
        case .imaging: "影像"
        case .visit: "复诊"
        case .maintenanceSwitch: "维持切换"
        }
    }
}

enum ScheduleEventStatus: String, Codable, CaseIterable {
    case pending
    case done
    case skipped
    case deferred

    var displayName: String {
        switch self {
        case .pending: "待完成"
        case .done: "已完成"
        case .skipped: "已跳过"
        case .deferred: "已延后"
        }
    }
}

/// 兼容旧称
typealias EventStatus = ScheduleEventStatus

enum MealTiming: String, Codable, CaseIterable {
    case before
    case withMeal
    case after
    case any

    var displayName: String {
        switch self {
        case .before: "餐前"
        case .withMeal: "餐中"
        case .after: "餐后"
        case .any: "不限"
        }
    }

    var reminderSuffix: String {
        switch self {
        case .before: "请在餐前按医嘱服用，如与医嘱不符以医嘱为准"
        case .withMeal: "请在餐中按医嘱服用，如与医嘱不符以医嘱为准"
        case .after: "请在餐后30分钟内服用，如与医嘱不符以医嘱为准"
        case .any: "请按医嘱时间服用，如与医嘱不符以医嘱为准"
        }
    }
}

enum ReportType: String, Codable, CaseIterable {
    case lab
    case pathology
    case imaging
    case order
    case discharge
    case genetic
    case invoice

    var displayName: String {
        switch self {
        case .lab: "检验"
        case .pathology: "病理"
        case .imaging: "影像"
        case .order: "医嘱"
        case .discharge: "出院小结"
        case .genetic: "基因检测"
        case .invoice: "发票/费用"
        }
    }
}

enum OstomyConsistency: String, Codable, CaseIterable {
    case watery
    case paste
    case formed

    var displayName: String {
        switch self {
        case .watery: "稀"
        case .paste: "糊"
        case .formed: "成形"
        }
    }
}

enum RegimenCategory: String, Codable, CaseIterable, Identifiable {
    case chemotherapy
    case targeted
    case inhibitor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chemotherapy: "化疗方案"
        case .targeted: "靶向药"
        case .inhibitor: "抑制剂"
        }
    }
}

enum TreatmentLineKind: Int, Codable, CaseIterable {
    case first = 1
    case second = 2
    case third = 3
    case maintenance = 0

    var displayName: String {
        switch self {
        case .first: "一线"
        case .second: "二线"
        case .third: "三线/后线"
        case .maintenance: "维持"
        }
    }
}

/// 兼容旧称
typealias RegimenLine = TreatmentLineKind
