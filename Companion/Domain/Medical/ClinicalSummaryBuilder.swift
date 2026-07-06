import Foundation
import SwiftData

enum ClinicalSummaryBuilder {
    static func doctorPrepPoints(
        activeRegimens: [RegimenInstance],
        latestCheckIn: SymptomLog?,
        recentLabs: [LabResult],
        recentReports: [MedicalReport]
    ) -> [String] {
        var points: [String] = []

        if activeRegimens.isEmpty {
            points.append("当前无活跃治疗方案，请向医生说明近期变化。")
        } else if activeRegimens.count == 1, let regimen = activeRegimens.first {
            points.append("当前方案：\(regimen.displayName)（\(regimen.line.displayName)），第 \(regimen.currentCycleIndex) 周期。")
        } else {
            let summary = activeRegimens.map {
                "\($0.displayName)（\($0.line.displayName)，第 \($0.currentCycleIndex) 周期）"
            }.joined(separator: "；")
            points.append("当前方案（\(activeRegimens.count) 项）：\(summary)。")
        }

        if let log = latestCheckIn {
            var symptom = "近日打卡：腹痛 \(log.pain)/10"
            if let fever = log.fever { symptom += "，体温 \(String(format: "%.1f", fever))℃" }
            symptom += "，关注等级 \(log.riskLevel.displayName)。"
            points.append(symptom)
        } else {
            points.append("近日尚未症状打卡，可向医生补充主观感受。")
        }

        let abnormalLabs = recentLabs.filter(\.isOutOfRange)
        if !abnormalLabs.isEmpty {
            let details = abnormalLabs.prefix(6).map { formatAbnormalLab($0) }.joined(separator: "；")
            points.append("报告异常检验（请重点沟通）：\(details)。")
        }

        let cea = recentLabs.filter { LabTypeNormalizer.isCEA($0.labType) }
        if let latestCEA = cea.first, !abnormalLabs.contains(where: { LabTypeNormalizer.isCEA($0.labType) }) {
            points.append("最近 CEA：\(String(format: "%.1f", latestCEA.value)) \(latestCEA.unit)（\(latestCEA.collectedAt.formatted(date: .abbreviated, time: .omitted))）。")
        }

        if let anc = recentLabs.first(where: { ["WBC", "ANC"].contains(LabTypeNormalizer.code(for: $0.labType)) }) {
            if !abnormalLabs.contains(where: { $0.persistentModelID == anc.persistentModelID }) {
                points.append("最近 \(anc.displayLabel)：\(String(format: "%.1f", anc.value)) \(anc.unit)。")
            }
        }

        let abnormalReports = reportsWithAbnormalLabs(recentReports, labs: recentLabs)
        if !abnormalReports.isEmpty {
            let titles = abnormalReports.prefix(3).map(\.title).joined(separator: "；")
            points.append("近期含异常项的报告：\(titles)。")
        }

        points.append("就诊诉求：请医生帮助评估是否按计划治疗、是否需要调整剂量或加验。")
        return Array(points.prefix(8))
    }

    private static func formatAbnormalLab(_ lab: LabResult) -> String {
        let rangeNote = LabReferenceRanges.rangeLabel(for: lab.labType, low: lab.refRangeLow, high: lab.refRangeHigh)
            .map { "，参考 \($0)" } ?? ""
        let direction = lab.value > (lab.effectiveRefRangeHigh ?? .infinity) ? "偏高" : "偏低"
        return "\(lab.displayLabel) \(String(format: "%.2f", lab.value)) \(lab.unit)（\(direction)\(rangeNote)）"
    }

    private static func reportsWithAbnormalLabs(_ reports: [MedicalReport], labs: [LabResult]) -> [MedicalReport] {
        reports.filter { report in
            labs.contains { lab in
                lab.sourceReport?.persistentModelID == report.persistentModelID && lab.isOutOfRange
            }
        }
    }

    static func exportSummary(
        activeRegimens: [RegimenInstance],
        ceaResults: [LabResult],
        recentLabs: [LabResult],
        checkIns: [SymptomLog],
        biomarkerNote: String?
    ) -> String {
        var lines: [String] = ["【伴行 · 就诊摘要】", ""]
        if activeRegimens.isEmpty {
            lines.append("方案：无活跃方案")
        } else if activeRegimens.count == 1, let regimen = activeRegimens.first {
            lines.append("方案：\(regimen.displayName) · \(regimen.line.displayName)")
        } else {
            lines.append("方案：\(activeRegimens.map { "\($0.displayName)（\($0.line.displayName)）" }.joined(separator: " + "))")
        }
        if let biomarkerNote { lines.append("标志物：\(biomarkerNote)") }
        lines.append("")

        if !ceaResults.isEmpty {
            lines.append("CEA 趋势（近\(ceaResults.count)次）：")
            for lab in ceaResults.prefix(8).reversed() {
                lines.append("  · \(lab.collectedAt.formatted(date: .abbreviated, time: .omitted))  \(lab.value) \(lab.unit)")
            }
            lines.append("")
        }

        let abnormal = recentLabs.filter(\.isOutOfRange)
        if !abnormal.isEmpty {
            lines.append("近期异常检验：")
            for lab in abnormal.prefix(8) {
                lines.append("  · \(lab.displayLabel) \(lab.value) \(lab.unit)")
            }
            lines.append("")
        }

        if let last = checkIns.first {
            lines.append("最近打卡：\(last.date.formatted(date: .abbreviated, time: .omitted)) · \(last.riskLevel.displayName)")
        }

        lines.append("")
        lines.append(CopyStrings.disclaimerGlobal)
        return lines.joined(separator: "\n")
    }
}
