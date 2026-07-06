import SwiftUI
import SwiftData

struct DoctorPrepView: View {
    @Query(filter: #Predicate<RegimenInstance> { $0.isActive })
    private var activeRegimens: [RegimenInstance]

    @Query(sort: \SymptomLog.date, order: .reverse)
    private var checkIns: [SymptomLog]

    @Query(sort: \LabResult.collectedAt, order: .reverse)
    private var labs: [LabResult]

    @Query(sort: \MedicalReport.reportDate, order: .reverse)
    private var reports: [MedicalReport]

    private var points: [String] {
        ClinicalSummaryBuilder.doctorPrepPoints(
            activeRegimens: activeRegimens,
            latestCheckIn: checkIns.first,
            recentLabs: Array(labs.prefix(40)),
            recentReports: Array(reports.prefix(10))
        )
    }

    private var shareText: String {
        points.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }

    var body: some View {
        List {
            Section {
                Text("以下要点由你近期的记录整理而成，含检验异常与报告提示。就诊前可快速浏览或分享。请以医生判断为准。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("沟通要点") {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(point.contains("异常") ? AppTheme.riskRed : AppTheme.brandTeal)
                            .clipShape(Circle())
                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(point.contains("异常") ? .primary : .primary)
                    }
                    .padding(.vertical, 4)
                }
            }

            DisclaimerFooter()
        }
        .navigationTitle("与医生沟通")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DoctorPrepView()
    }
    .modelContainer(CompanionModelContainer.make(inMemory: true))
}
