import SwiftUI

struct LabReferenceSettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var editingCode: String?

    private var trackedMetrics: [TrendLabMetric] {
        settings.trackedLabMetricCodes.compactMap { LabTrendCatalog.metric(for: $0) }
    }

    var body: some View {
        List {
            Section {
                Text("自定义参考区间将覆盖内置默认值，并在趋势图中显示参考线。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if trackedMetrics.isEmpty {
                ContentUnavailableView(
                    "暂无追踪指标",
                    systemImage: "ruler",
                    description: Text("请先在「管理检验指标」中勾选项目。")
                )
            }

            ForEach(trackedMetrics) { metric in
                Button {
                    editingCode = metric.code
                } label: {
                    referenceRow(for: metric)
                }
            }
        }
        .navigationTitle("参考范围设置")
        .sheet(item: Binding(
            get: { editingCode.map { IdentifiableCode(code: $0) } },
            set: { editingCode = $0?.code }
        )) { item in
            ReferenceRangeEditorSheet(code: item.code)
        }
    }

    private func referenceRow(for metric: TrendLabMetric) -> some View {
        let code = metric.code
        let custom = settings.customReferenceRange(for: code)
        let defaultRange = LabReferenceRanges.defaultRange(for: code)
        let effectiveLow = custom?.low ?? defaultRange?.low
        let effectiveHigh = custom?.high ?? defaultRange?.high

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let effectiveLow, let effectiveHigh {
                    Text(formatRange(low: effectiveLow, high: effectiveHigh, unit: metric.defaultUnit, isCustom: custom != nil))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("无默认参考范围")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatRange(low: Double, high: Double, unit: String, isCustom: Bool) -> String {
        let lo = low == floor(low) ? String(format: "%.0f", low) : String(format: "%.1f", low)
        let hi = high == floor(high) ? String(format: "%.0f", high) : String(format: "%.1f", high)
        var text = "\(lo) – \(hi)"
        if !unit.isEmpty { text += " \(unit)" }
        if isCustom { text += "（自定义）" }
        return text
    }
}

private struct IdentifiableCode: Identifiable {
    let code: String
    var id: String { code }
}

private struct ReferenceRangeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared

    let code: String
    @State private var lowText = ""
    @State private var highText = ""

    private var metric: TrendLabMetric? { LabTrendCatalog.metric(for: code) }

    var body: some View {
        NavigationStack {
            Form {
                if let metric {
                    Section("指标") {
                        Text(metric.displayName)
                    }
                }

                Section("参考范围") {
                    TextField("下限", text: $lowText)
                        .keyboardType(.decimalPad)
                    TextField("上限", text: $highText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button("恢复默认", role: .destructive) {
                        settings.resetCustomReferenceRange(for: code)
                        loadValues()
                    }
                }
            }
            .navigationTitle("编辑参考范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear { loadValues() }
        }
    }

    private func loadValues() {
        if let custom = settings.customReferenceRange(for: code) {
            lowText = String(custom.low)
            highText = String(custom.high)
        } else if let defaultRange = LabReferenceRanges.defaultRange(for: code) {
            lowText = String(defaultRange.low)
            highText = String(defaultRange.high)
        }
    }

    private func save() {
        guard let low = Double(lowText.trimmingCharacters(in: .whitespaces)),
              let high = Double(highText.trimmingCharacters(in: .whitespaces)) else { return }
        settings.setCustomReferenceRange(for: code, low: low, high: high)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        LabReferenceSettingsView()
    }
}
