import SwiftUI
import SwiftData

struct ExportSummaryView: View {
    @Query(filter: #Predicate<RegimenInstance> { $0.isActive }, sort: \RegimenInstance.createdAt, order: .reverse)
    private var activeRegimens: [RegimenInstance]
    @Query(sort: \LabResult.collectedAt, order: .reverse) private var allLabs: [LabResult]
    @Query(sort: \SymptomLog.date, order: .reverse) private var checkIns: [SymptomLog]
    @Query(sort: \MedicalReport.reportDate, order: .reverse) private var reports: [MedicalReport]

    @State private var showShare = false
    @State private var exportText = ""

    private var ceaResults: [LabResult] {
        allLabs.filter { LabTypeNormalizer.isCEA($0.labType) }
    }

    var body: some View {
        Form {
            Section("预览") {
                ScrollView {
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 360)
            }

            Section("统计") {
                LabeledContent("活跃方案", value: "\(activeRegimens.count)")
                LabeledContent("打卡记录", value: "\(checkIns.count)")
                LabeledContent("检验指标", value: "\(allLabs.count)")
                LabeledContent("报告", value: "\(reports.count)")
            }

            Section {
                Button {
                    exportText = summaryText
                    showShare = true
                } label: {
                    Label("导出文本摘要", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("导出摘要")
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [exportText])
        }
    }

    private var summaryText: String {
        ClinicalSummaryBuilder.exportSummary(
            activeRegimens: activeRegimens,
            ceaResults: Array(ceaResults.prefix(12)),
            recentLabs: Array(allLabs.prefix(40)),
            checkIns: Array(checkIns.prefix(14)),
            biomarkerNote: biomarkerNote
        )
    }

    private var biomarkerNote: String? {
        for report in reports.prefix(5) {
            guard let json = report.extractedFieldsJSON,
                  let data = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let biomarkers = obj["biomarkers"] as? [String: String],
                  !biomarkers.isEmpty else { continue }
            return biomarkers.map { "\($0.key)：\($0.value)" }.joined(separator: "；")
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        ExportSummaryView()
    }
    .modelContainer(CompanionModelContainer.make(inMemory: true))
}
