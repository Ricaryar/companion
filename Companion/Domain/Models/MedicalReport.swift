import Foundation
import SwiftData

@Model
final class MedicalReport {
    var reportTypeRaw: String
    var title: String
    var reportDate: Date
    var filePath: String?
    var ocrText: String?
    var extractedFieldsJSON: String?
    var isPrivacyLocked: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LabResult.sourceReport)
    var labResults: [LabResult] = []

    var reportType: ReportType {
        get { ReportType(rawValue: reportTypeRaw) ?? .lab }
        set { reportTypeRaw = newValue.rawValue }
    }

    init(
        reportType: ReportType,
        title: String,
        reportDate: Date = .now,
        filePath: String? = nil,
        ocrText: String? = nil,
        extractedFieldsJSON: String? = nil,
        isPrivacyLocked: Bool = false,
        createdAt: Date = .now
    ) {
        self.reportTypeRaw = reportType.rawValue
        self.title = title
        self.reportDate = reportDate
        self.filePath = filePath
        self.ocrText = ocrText
        self.extractedFieldsJSON = extractedFieldsJSON
        self.isPrivacyLocked = isPrivacyLocked
        self.createdAt = createdAt
    }
}
