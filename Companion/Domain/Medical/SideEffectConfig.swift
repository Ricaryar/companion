import Foundation

struct SideEffectCatalog: Codable {
    let version: String
    let guidelineNote: String?
    let reviewedAt: String?
    let regimenDrugs: [String: [String]]
    let drugs: [DrugSideEffectProfile]
}

struct DrugSideEffectProfile: Codable, Identifiable {
    var id: String { code }
    let code: String
    let displayName: String
    let sideEffects: [SideEffectEntry]
}

struct SideEffectEntry: Codable, Identifiable {
    var id: String { "\(symptomKey)-\(label)" }
    let symptomKey: String
    let label: String
    let watchFor: [String]
    let selfCare: [String]
    let callDoctor: [String]
    let sources: [String]
}

/// 与 SymptomLog 打卡字段的对应关系
enum SideEffectSymptomKey: String, CaseIterable {
    case cipn
    case hfs
    case nausea
    case vomiting
    case diarrhea
    case fever
    case pain
    case bleeding

    var checkInLabel: String? {
        switch self {
        case .cipn: "周围神经病变"
        case .hfs: "手足综合征"
        case .nausea: "恶心"
        case .vomiting: "呕吐"
        case .diarrhea: "排便次数"
        case .fever: "体温"
        case .pain: "腹痛"
        case .bleeding: "便血/黑便"
        }
    }

    var isTrackedInCheckIn: Bool {
        checkInLabel != nil
    }
}

struct AggregatedSideEffect: Identifiable {
    let id: String
    let entry: SideEffectEntry
    let drugNames: [String]
}
