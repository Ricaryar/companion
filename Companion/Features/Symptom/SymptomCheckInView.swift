import SwiftUI
import SwiftData

struct SymptomCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<RegimenInstance> { $0.isActive })
    private var activeRegimens: [RegimenInstance]

    @State private var pain = 0
    @State private var feverText = ""
    @State private var stoolCount = 0
    @State private var bristolType = 4
    @State private var hasBleeding = false
    @State private var nauseaCount = 0
    @State private var vomitCount = 0
    @State private var cipn = 0
    @State private var hfsGrade = 0
    @State private var weightText = ""
    @State private var waterIntake = 1500
    @State private var notes = ""
    @State private var showBristolGuide: Bool = AppSettings.shared.showBristolGuide

    private let evaluator = RiskEvaluator()

    private var regimenWatchTips: [AggregatedSideEffect] {
        SideEffectRepository.shared.checkInRelevantTips(
            forRegimenCodes: activeRegimens.map(\.regimenCode)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if !regimenWatchTips.isEmpty {
                    Section {
                        ForEach(regimenWatchTips.prefix(4)) { tip in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(tip.entry.label)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(tip.drugNames.joined(separator: "、"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Text(tip.entry.watchFor.prefix(2).joined(separator: "；"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        NavigationLink {
                            SideEffectTipsView(activeRegimens: activeRegimens)
                        } label: {
                            Text("查看全部副作用应对")
                        }
                    } header: {
                        Label("当前方案需关注", systemImage: "exclamationmark.triangle")
                    } footer: {
                        Text("带 checklist 标记的项目可在下方打卡中记录。")
                            .font(.caption2)
                    }
                }

                Section("核心症状") {
                    Stepper("腹痛 \(pain)/10", value: $pain, in: 0...10)
                    TextField("体温（℃，可选）", text: $feverText)
                        .keyboardType(.decimalPad)
                    Toggle("便血/黑便", isOn: $hasBleeding)
                }

                Section("消化道") {
                    Stepper("今日排便 \(stoolCount) 次", value: $stoolCount, in: 0...20)
                    Stepper("布里斯托分型 \(bristolType)", value: $bristolType, in: 1...7)
                    if showBristolGuide {
                        Text("1=硬块 … 7=水样，4 为理想成形便。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Stepper("恶心 \(nauseaCount) 次", value: $nauseaCount, in: 0...10)
                    Stepper("呕吐 \(vomitCount) 次", value: $vomitCount, in: 0...10)
                }

                Section("治疗相关") {
                    Stepper("周围神经病变 \(cipn)/10", value: $cipn, in: 0...10)
                    Stepper("手足综合征 \(hfsGrade) 级", value: $hfsGrade, in: 0...3)
                }

                Section("其他") {
                    TextField("体重（kg，可选）", text: $weightText)
                        .keyboardType(.decimalPad)
                    Stepper("饮水 \(waterIntake) ml", value: $waterIntake, in: 0...5000, step: 100)
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    riskPreview
                }
            }
            .navigationTitle(CopyStrings.checkIn)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveEntry() }
                }
            }
        }
    }

    private var riskPreview: some View {
        let draft = buildDraftLog()
        let level = evaluator.evaluate(draft)
        return HStack {
            Text("预估关注等级")
            Spacer()
            Text(level.displayName)
                .fontWeight(.semibold)
                .foregroundStyle(RiskLevelColor.color(for: level))
        }
    }

    private func buildDraftLog() -> SymptomLog {
        SymptomLog(
            fever: parseDouble(feverText),
            pain: pain,
            stoolCount: stoolCount,
            bristolType: bristolType,
            hasBleeding: hasBleeding,
            nauseaCount: nauseaCount,
            vomitCount: vomitCount,
            cipn: cipn,
            hfsGrade: hfsGrade,
            weightKg: parseDouble(weightText),
            waterIntakeML: waterIntake,
            notes: notes.isEmpty ? nil : notes
        )
    }

    private func saveEntry() {
        let log = buildDraftLog()
        log.riskLevel = evaluator.evaluate(log)
        modelContext.insert(log)
        try? modelContext.save()
        dismiss()
    }

    private func parseDouble(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces))
    }
}

#Preview {
    SymptomCheckInView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
