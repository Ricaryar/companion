import Foundation
import SwiftData
import UIKit

enum ReportImportService {
    @MainActor
    static func saveParsed(
        parse: ReportParseResult,
        image: UIImage,
        context: ModelContext,
        manualTitle: String? = nil,
        manualType: ReportType? = nil,
        manualDate: Date? = nil,
        labs: [ExtractedLabValue]? = nil
    ) throws -> MedicalReport {
        let labsToSave = labs ?? parse.labs
        let fileName = try ReportFileStore.saveImage(image)

        let reportType = manualType ?? parse.reportType
        let reportDate = manualDate ?? parse.reportDate
        let title = (manualTitle?.isEmpty == false ? manualTitle! : parse.suggestedTitle)

        let fields: [String: Any] = [
            "labs": labsToSave.map { ["type": $0.labType, "value": $0.value, "unit": $0.unit] },
            "biomarkers": parse.biomarkers,
            "parsedAt": ISO8601DateFormatter().string(from: Date())
        ]
        let fieldsJSON = (try? JSONSerialization.data(withJSONObject: fields)).flatMap {
            String(data: $0, encoding: .utf8)
        }

        let report = MedicalReport(
            reportType: reportType,
            title: title,
            reportDate: reportDate,
            filePath: fileName,
            ocrText: parse.rawText,
            extractedFieldsJSON: fieldsJSON,
            isPrivacyLocked: reportType == .genetic || reportType == .pathology
        )
        context.insert(report)
        let reportKey = report.stableKey

        for lab in labsToSave {
            let result = LabResult(
                labType: lab.labType,
                value: lab.value,
                unit: lab.unit,
                refRangeLow: lab.refRangeLow,
                refRangeHigh: lab.refRangeHigh,
                collectedAt: reportDate,
                normalizedValue: lab.value,
                normalizedUnit: lab.unit,
                sourceReportKey: reportKey,
                sourceReport: report
            )
            context.insert(result)
            report.labResults.append(result)
        }

        try context.save()
        trackImportedLabCodes(labsToSave)
        return report
    }

    private static func trackImportedLabCodes(_ labs: [ExtractedLabValue]) {
        var tracked = AppSettings.shared.trackedLabMetricCodes
        var visible: [String] = []
        for lab in labs {
            let code = LabTypeNormalizer.code(for: lab.labType)
            if !tracked.contains(code) { tracked.append(code) }
            visible.append(code)
        }
        AppSettings.shared.trackedLabMetricCodes = tracked
        AppSettings.shared.visibleLabMetricCodes = visible.isEmpty ? tracked : visible
    }

    @MainActor
    static func saveManual(
        context: ModelContext,
        title: String,
        reportType: ReportType,
        reportDate: Date,
        image: UIImage?,
        fileData: Data?,
        fileName: String?,
        parse: ReportParseResult?,
        labs: [ExtractedLabValue]?
    ) throws -> MedicalReport {
        let storedPath: String?
        if let image {
            storedPath = try ReportFileStore.saveImage(image)
        } else if let fileData, let fileName {
            storedPath = try ReportFileStore.saveFile(data: fileData, originalName: fileName)
        } else {
            throw ReportStoreError.fileNotFound
        }

        let labsToSave = labs ?? parse?.labs ?? []
        let fields: [String: Any] = [
            "labs": labsToSave.map { ["type": $0.labType, "value": $0.value, "unit": $0.unit] },
            "biomarkers": parse?.biomarkers ?? [:],
            "parsedAt": ISO8601DateFormatter().string(from: Date())
        ]
        let fieldsJSON = (try? JSONSerialization.data(withJSONObject: fields)).flatMap {
            String(data: $0, encoding: .utf8)
        }

        let report = MedicalReport(
            reportType: reportType,
            title: title,
            reportDate: reportDate,
            filePath: storedPath,
            ocrText: parse?.rawText,
            extractedFieldsJSON: fieldsJSON,
            isPrivacyLocked: reportType == .genetic || reportType == .pathology
        )
        context.insert(report)
        let reportKey = report.stableKey

        for lab in labsToSave {
            let result = LabResult(
                labType: lab.labType,
                value: lab.value,
                unit: lab.unit,
                refRangeLow: lab.refRangeLow,
                refRangeHigh: lab.refRangeHigh,
                collectedAt: reportDate,
                normalizedValue: lab.value,
                normalizedUnit: lab.unit,
                sourceReportKey: reportKey,
                sourceReport: report
            )
            context.insert(result)
            report.labResults.append(result)
        }

        try context.save()
        if !labsToSave.isEmpty {
            trackImportedLabCodes(labsToSave)
        }
        return report
    }

    @MainActor
    static func reparseExisting(
        report: MedicalReport,
        image: UIImage,
        context: ModelContext
    ) async throws -> ReportParseResult {
        let parse = try await ReportOCRService.parseReport(from: image)

        for lab in report.labResults {
            context.delete(lab)
        }
        report.labResults.removeAll()

        report.ocrText = parse.rawText
        report.reportDate = parse.reportDate
        report.reportType = parse.reportType
        if report.title.isEmpty || report.title.contains("检验") {
            report.title = parse.suggestedTitle
        }

        let fields: [String: Any] = [
            "labs": parse.labs.map { ["type": $0.labType, "value": $0.value, "unit": $0.unit] },
            "biomarkers": parse.biomarkers,
            "parsedAt": ISO8601DateFormatter().string(from: Date())
        ]
        report.extractedFieldsJSON = (try? JSONSerialization.data(withJSONObject: fields)).flatMap {
            String(data: $0, encoding: .utf8)
        }

        let reportKey = report.stableKey
        for lab in parse.labs {
            let result = LabResult(
                labType: lab.labType,
                value: lab.value,
                unit: lab.unit,
                refRangeLow: lab.refRangeLow,
                refRangeHigh: lab.refRangeHigh,
                collectedAt: parse.reportDate,
                normalizedValue: lab.value,
                normalizedUnit: lab.unit,
                sourceReportKey: reportKey,
                sourceReport: report
            )
            context.insert(result)
            report.labResults.append(result)
        }

        try context.save()
        trackImportedLabCodes(parse.labs)
        return parse
    }
}
