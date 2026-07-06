import SwiftUI
import SwiftData

struct MedicalRecordsView: View {
    @Query(sort: \MedicalReport.reportDate, order: .reverse) private var reports: [MedicalReport]
    @State private var showAddReport = false

    var body: some View {
        NavigationStack {
            Group {
                if reports.isEmpty {
                    ContentUnavailableView(
                        "暂无报告",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("拍照上传检验报告，自动识别指标。")
                    )
                } else {
                    List(reports) { report in
                        NavigationLink {
                            ReportDetailView(report: report)
                        } label: {
                            reportRow(report)
                        }
                    }
                }
            }
            .navigationTitle("医疗记录")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showAddReport = true } label: {
                            Label(CopyStrings.addReport, systemImage: "camera")
                        }
                        NavigationLink {
                            LabTrendsView()
                        } label: {
                            Label("指标趋势", systemImage: "chart.xyaxis.line")
                        }
                        NavigationLink {
                            AddLabValueView()
                        } label: {
                            Label("手动录入", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddReport) {
                AddReportView()
            }
        }
    }

    private func reportRow(_ report: MedicalReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(report.title)
                    .font(.headline)
                if report.isPrivacyLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(report.reportType.displayName)
                Text("·")
                Text(report.reportDate, format: .dateTime.year().month().day())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("\(report.labResults.count) 项指标")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MedicalRecordsView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
