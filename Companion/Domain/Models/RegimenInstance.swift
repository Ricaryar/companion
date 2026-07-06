import Foundation
import SwiftData

@Model
final class RegimenInstance {
    var regimenCode: String
    var displayName: String
    var lineRaw: Int
    var isMaintenance: Bool
    var startDate: Date
    var cycleDays: Int
    var currentCycleIndex: Int
    var shiftDays: Int
    var isActive: Bool
    var endedAt: Date?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ScheduleEvent.regimen)
    var events: [ScheduleEvent] = []

    var line: TreatmentLineKind {
        get { TreatmentLineKind(rawValue: lineRaw) ?? .first }
        set { lineRaw = newValue.rawValue }
    }

    init(
        regimenCode: String,
        displayName: String,
        line: TreatmentLineKind = .first,
        isMaintenance: Bool = false,
        startDate: Date,
        cycleDays: Int,
        currentCycleIndex: Int = 1,
        shiftDays: Int = 0,
        isActive: Bool = true,
        endedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.regimenCode = regimenCode
        self.displayName = displayName
        self.lineRaw = line.rawValue
        self.isMaintenance = isMaintenance
        self.startDate = startDate
        self.cycleDays = cycleDays
        self.currentCycleIndex = currentCycleIndex
        self.shiftDays = shiftDays
        self.isActive = isActive
        self.endedAt = endedAt
        self.createdAt = createdAt
    }
}
