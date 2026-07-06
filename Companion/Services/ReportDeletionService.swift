import Foundation
import SwiftData

enum ReportDeletionService {
    /// 删除报告、本地图片，以及该报告导入/识别产生的全部检验记录。
    @MainActor
    static func delete(_ report: MedicalReport, in context: ModelContext) {
        let reportKey = report.stableKey
        let snapshotTypes = labTypesFromReport(report)
        let allLabs = (try? context.fetch(FetchDescriptor<LabResult>())) ?? []

        for lab in allLabs {
            if shouldDelete(lab: lab, report: report, reportKey: reportKey, snapshotTypes: snapshotTypes) {
                context.delete(lab)
            }
        }

        if let path = report.filePath {
            ReportFileStore.deleteFile(storedPath: path)
        }
        context.delete(report)
        try? context.save()
    }

    private static func shouldDelete(
        lab: LabResult,
        report: MedicalReport,
        reportKey: String,
        snapshotTypes: Set<String>
    ) -> Bool {
        if lab.sourceReportKey == reportKey { return true }
        if lab.sourceReport?.persistentModelID == report.persistentModelID { return true }

        // 兼容旧数据：无关联键但类型+日期与该报告快照一致
        if lab.sourceReport == nil,
           (lab.sourceReportKey == nil || lab.sourceReportKey?.isEmpty == true),
           !snapshotTypes.isEmpty,
           matchesOrphanedSnapshot(lab: lab, report: report, types: snapshotTypes) {
            return true
        }
        return false
    }

    private static func matchesOrphanedSnapshot(
        lab: LabResult,
        report: MedicalReport,
        types: Set<String>
    ) -> Bool {
        let code = LabTypeNormalizer.code(for: lab.labType)
        guard types.contains(code) else { return false }
        return Calendar.current.isDate(lab.collectedAt, inSameDayAs: report.reportDate)
    }

    private static func labTypesFromReport(_ report: MedicalReport) -> Set<String> {
        guard let json = report.extractedFieldsJSON,
              let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let labs = obj["labs"] as? [[String: Any]] else {
            return Set(report.labResults.map { LabTypeNormalizer.code(for: $0.labType) })
        }
        return Set(labs.compactMap { item in
            guard let type = item["type"] as? String else { return nil }
            return LabTypeNormalizer.code(for: type)
        })
    }
}

extension MedicalReport {
    var stableKey: String {
        String(describing: persistentModelID)
    }
}
