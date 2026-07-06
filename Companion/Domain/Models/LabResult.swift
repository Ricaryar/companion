import Foundation
import SwiftData

@Model
final class LabResult {
    var labType: String
    var value: Double
    var unit: String
    var refRangeLow: Double?
    var refRangeHigh: Double?
    var collectedAt: Date
    var normalizedValue: Double?
    var normalizedUnit: String?

    /// 所属报告的稳定标识，用于删除报告时可靠清理检验数据
    var sourceReportKey: String?

    var sourceReport: MedicalReport?

    init(
        labType: String,
        value: Double,
        unit: String,
        refRangeLow: Double? = nil,
        refRangeHigh: Double? = nil,
        collectedAt: Date = .now,
        normalizedValue: Double? = nil,
        normalizedUnit: String? = nil,
        sourceReportKey: String? = nil,
        sourceReport: MedicalReport? = nil
    ) {
        self.labType = labType
        self.value = value
        self.unit = unit
        self.refRangeLow = refRangeLow
        self.refRangeHigh = refRangeHigh
        self.collectedAt = collectedAt
        self.normalizedValue = normalizedValue
        self.normalizedUnit = normalizedUnit
        self.sourceReportKey = sourceReportKey
        self.sourceReport = sourceReport
    }

    var isManualEntry: Bool {
        sourceReport == nil && sourceReportKey == nil
    }

    var effectiveRefRangeLow: Double? {
        refRangeLow ?? LabReferenceRanges.effectiveRange(for: labType)?.low
    }

    var effectiveRefRangeHigh: Double? {
        refRangeHigh ?? LabReferenceRanges.effectiveRange(for: labType)?.high
    }

    var chineseName: String {
        LabTrendCatalog.chineseName(for: labType)
    }

    var displayLabel: String {
        LabTrendCatalog.displayName(for: labType)
    }

    var isOutOfRange: Bool {
        LabReferenceRanges.isOutOfRange(
            value: value,
            low: refRangeLow,
            high: refRangeHigh,
            labType: labType
        )
    }
}
