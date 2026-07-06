import SwiftUI
import SwiftData

struct AddLabValueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var preselectedCode: String = "CEA"

    @State private var selectedCode: String
    @State private var collectedAt = Date()
    @State private var valueText = ""
    @State private var unit: String
    @State private var refLowText = ""
    @State private var refHighText = ""

    init(preselectedCode: String = "CEA") {
        self.preselectedCode = preselectedCode
        _selectedCode = State(initialValue: preselectedCode)
        _unit = State(initialValue: LabTrendCatalog.metric(for: preselectedCode)?.defaultUnit ?? "")
    }

    var body: some View {
        Form {
            Section("检验项目") {
                Picker("项目", selection: $selectedCode) {
                    ForEach(LabTrendCatalog.all) { metric in
                        Text(metric.displayName).tag(metric.code)
                    }
                }
                .onChange(of: selectedCode) { _, code in
                    if let metric = LabTrendCatalog.metric(for: code) {
                        unit = metric.defaultUnit
                    }
                }
            }

            Section("数值") {
                DatePicker("检验日期", selection: $collectedAt, displayedComponents: .date)
                TextField("结果", text: $valueText)
                    .keyboardType(.decimalPad)
                TextField("单位", text: $unit)
            }

            Section("参考范围（可选）") {
                TextField("下限", text: $refLowText)
                    .keyboardType(.decimalPad)
                TextField("上限", text: $refHighText)
                    .keyboardType(.decimalPad)
            }

            Section {
                Text("手动记录会出现在趋势图中，并与报告 OCR 数据一并展示。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("添加检验记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        guard let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) else { return false }
        return value > 0 && !unit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        guard let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) else { return }
        let refLow = Double(refLowText.replacingOccurrences(of: ",", with: "."))
            ?? LabReferenceRanges.defaultRange(for: selectedCode)?.low
        let refHigh = Double(refHighText.replacingOccurrences(of: ",", with: "."))
            ?? LabReferenceRanges.defaultRange(for: selectedCode)?.high

        let result = LabResult(
            labType: selectedCode,
            value: value,
            unit: unit.trimmingCharacters(in: .whitespaces),
            refRangeLow: refLow,
            refRangeHigh: refHigh,
            collectedAt: collectedAt,
            normalizedValue: value,
            normalizedUnit: unit,
            sourceReport: nil
        )
        contextInsertAndTrack(result)
        try? modelContext.save()
        dismiss()
    }

    private func contextInsertAndTrack(_ result: LabResult) {
        modelContext.insert(result)
        var codes = AppSettings.shared.trackedLabMetricCodes
        if !codes.contains(selectedCode) {
            codes.append(selectedCode)
            AppSettings.shared.trackedLabMetricCodes = codes
        }
    }
}
