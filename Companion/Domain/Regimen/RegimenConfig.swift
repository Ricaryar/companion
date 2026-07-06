import Foundation

struct RegimenCatalog: Codable {
    let version: String
    let guidelineNote: String?
    let categories: [RegimenCategoryDef]
    let regimens: [RegimenDef]
}

struct RegimenCategoryDef: Codable, Identifiable {
    var id: String { code }
    let code: String
    let displayName: String
    let sortOrder: Int
}

struct RegimenDef: Codable, Identifiable {
    var id: String { code }
    let code: String
    let displayName: String
    let category: String
    let summary: String?
    let biomarkerHint: String?
    let cycleDays: Int
    let supportedLines: [Int]
    let isMaintenanceOption: Bool
    let primaryEligible: Bool?
    let allowAsAddon: Bool?
    let addonOnly: Bool?
    let events: [RegimenEventTemplate]
    let checkups: [RegimenCheckupTemplate]

    var regimenCategory: RegimenCategory {
        RegimenCategory(rawValue: category) ?? .chemotherapy
    }

    /// 可作为「主方案」单选
    var canUseAsPrimary: Bool {
        if addonOnly == true { return false }
        return primaryEligible ?? true
    }

    /// 可作为「加用」多选（后线/个体化组合）
    var canUseAsAddon: Bool {
        allowAsAddon == true
    }
}

struct RegimenEventTemplate: Codable {
    let type: String
    let dayOffset: Int
    let hour: Int
    let minute: Int
    let title: String
    let mealTiming: String?
    let repeatEveryCycle: Bool
}

struct RegimenCheckupTemplate: Codable {
    let type: String
    let labType: String?
    let dayOffset: Int
    let hour: Int
    let minute: Int
    let title: String
}

struct RiskRulesCatalog: Codable {
    let version: String
    let symptomRules: SymptomRiskRules
    let ostomyRules: OstomyRiskRules
}

struct SymptomRiskRules: Codable {
    let feverRedC: Double
    let feverYellowLowC: Double
    let feverYellowHighC: Double
    let painRed: Int
    let painYellow: Int
    let diarrheaRedPerDay: Int
    let diarrheaYellowLow: Int
    let diarrheaYellowHigh: Int
    let vomitRedPerDay: Int
    let cipnRed: Int
    let cipnYellowLow: Int
    let cipnYellowHigh: Int
}

struct OstomyRiskRules: Codable {
    let baselineDays: Int
    let emptiesIncreaseYellow: Int
    let emptiesIncreaseRed: Int
}
