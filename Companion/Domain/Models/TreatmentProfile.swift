import Foundation
import SwiftData

@Model
final class TreatmentProfile {
    var primarySite: String
    var stageScenario: String
    var rasStatus: String?
    var brafStatus: String?
    var msiStatus: String?
    var her2Status: String?
    var pdl1Status: String?
    var hasOstomy: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        primarySite: String = "",
        stageScenario: String = "",
        rasStatus: String? = nil,
        brafStatus: String? = nil,
        msiStatus: String? = nil,
        her2Status: String? = nil,
        pdl1Status: String? = nil,
        hasOstomy: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.primarySite = primarySite
        self.stageScenario = stageScenario
        self.rasStatus = rasStatus
        self.brafStatus = brafStatus
        self.msiStatus = msiStatus
        self.her2Status = her2Status
        self.pdl1Status = pdl1Status
        self.hasOstomy = hasOstomy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
