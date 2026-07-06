import Foundation
import SwiftData

@Model
final class SymptomLog {
    var date: Date
    var fever: Double?
    var pain: Int
    var stoolCount: Int
    var bristolType: Int
    var hasBleeding: Bool
    var nauseaCount: Int
    var vomitCount: Int
    var cipn: Int
    var hfsGrade: Int
    var weightKg: Double?
    var waterIntakeML: Int?
    var notes: String?
    var riskLevelRaw: String

    var riskLevel: RiskLevel {
        get { RiskLevel(rawValue: riskLevelRaw) ?? .green }
        set { riskLevelRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        fever: Double? = nil,
        pain: Int = 0,
        stoolCount: Int = 0,
        bristolType: Int = 4,
        hasBleeding: Bool = false,
        nauseaCount: Int = 0,
        vomitCount: Int = 0,
        cipn: Int = 0,
        hfsGrade: Int = 0,
        weightKg: Double? = nil,
        waterIntakeML: Int? = nil,
        notes: String? = nil,
        riskLevel: RiskLevel = .green
    ) {
        self.date = date
        self.fever = fever
        self.pain = pain
        self.stoolCount = stoolCount
        self.bristolType = bristolType
        self.hasBleeding = hasBleeding
        self.nauseaCount = nauseaCount
        self.vomitCount = vomitCount
        self.cipn = cipn
        self.hfsGrade = hfsGrade
        self.weightKg = weightKg
        self.waterIntakeML = waterIntakeML
        self.notes = notes
        self.riskLevelRaw = riskLevel.rawValue
    }
}
