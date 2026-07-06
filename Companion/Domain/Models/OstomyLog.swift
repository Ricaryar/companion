import Foundation
import SwiftData

@Model
final class OstomyLog {
    var date: Date
    var emptiesCount: Int
    var avgFillLevel: Double
    var consistencyRaw: String
    var nighttimeEmpties: Int
    var wearHours: Double?
    var hasLeakage: Bool
    var skinStatus: String?
    var notes: String?
    var estVolumeMinML: Int?
    var estVolumeMaxML: Int?

    var consistency: OstomyConsistency {
        get { OstomyConsistency(rawValue: consistencyRaw) ?? .paste }
        set { consistencyRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        emptiesCount: Int = 0,
        avgFillLevel: Double = 0.5,
        consistency: OstomyConsistency = .paste,
        nighttimeEmpties: Int = 0,
        wearHours: Double? = nil,
        hasLeakage: Bool = false,
        skinStatus: String? = nil,
        notes: String? = nil,
        estVolumeMinML: Int? = nil,
        estVolumeMaxML: Int? = nil
    ) {
        self.date = date
        self.emptiesCount = emptiesCount
        self.avgFillLevel = avgFillLevel
        self.consistencyRaw = consistency.rawValue
        self.nighttimeEmpties = nighttimeEmpties
        self.wearHours = wearHours
        self.hasLeakage = hasLeakage
        self.skinStatus = skinStatus
        self.notes = notes
        self.estVolumeMinML = estVolumeMinML
        self.estVolumeMaxML = estVolumeMaxML
    }
}
