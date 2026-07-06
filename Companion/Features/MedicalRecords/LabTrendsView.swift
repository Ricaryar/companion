import SwiftUI
import SwiftData
import Charts

struct LabTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabResult.collectedAt) private var allResults: [LabResult]
    @Query(filter: #Predicate<RegimenInstance> { $0.isActive }, sort: \RegimenInstance.startDate, order: .reverse)
    private var activeRegimens: [RegimenInstance]

    @Bindable private var settings = AppSettings.shared
    @State private var showAddLab = false
    @State private var showAddReport = false
    @State private var addLabPreselectedCode: String?

    private var trackedCodes: [String] {
        _ = settings.settingsChangeToken
        return settings.trackedLabMetricCodes
    }

    private var visibleCodes: [String] {
        _ = settings.settingsChangeToken
        return settings.visibleLabMetricCodes
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                metricCapsuleBar
                cycleAlignToggle

                if trackedCodes.isEmpty {
                    emptyTrendsPlaceholder(
                        title: "选择趋势项目",
                        message: "点击上方 + 管理趋势项目，或导入报告后自动添加。"
                    )
                } else if visibleCodes.isEmpty {
                    emptyTrendsPlaceholder(
                        title: "选择要查看的指标",
                        message: "点击胶囊标签查看对应趋势图。"
                    )
                } else {
                    Text("共 \(visibleCodes.count) 项指标")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ForEach(visibleCodes, id: \.self) { code in
                        metricSection(for: code)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("趋势")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        addLabPreselectedCode = visibleCodes.first ?? trackedCodes.first ?? "CEA"
                        showAddLab = true
                    } label: {
                        Label("手动添加记录", systemImage: "plus.circle")
                    }
                    Button { showAddReport = true } label: {
                        Label("拍照导入报告", systemImage: "camera")
                    }
                    NavigationLink {
                        DocumentsLibraryView(navigationTitle: "报告库")
                    } label: {
                        Label("报告库", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddLab) {
            NavigationStack {
                AddLabValueView(preselectedCode: addLabPreselectedCode ?? "CEA")
            }
        }
        .sheet(isPresented: $showAddReport) {
            AddReportView()
        }
    }

    private var metricCapsuleBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(trackedCodes, id: \.self) { code in
                    let isVisible = settings.isVisibleLabMetric(code)
                    Button {
                        settings.toggleVisibleLabMetric(code)
                    } label: {
                        Text(LabTrendCatalog.shortLabel(for: code))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isVisible ? AppTheme.brandTeal : AppTheme.cardBackground)
                            .foregroundStyle(isVisible ? .white : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isVisible ? Color.clear : AppTheme.brandTeal.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    ManageLabMetricsView()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.brandTeal)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var cycleAlignToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.alignLabsToCycle },
            set: { settings.alignLabsToCycle = $0 }
        )) {
            Text("与治疗周期对齐（C1D1 等）")
                .font(.subheadline)
        }
        .padding(.horizontal)
        .disabled(activeRegimens.isEmpty)
    }

    private func metricSection(for code: String) -> some View {
        let normalized = LabTypeNormalizer.code(for: code)
        let dataPoints = allResults
            .filter { LabTypeNormalizer.code(for: $0.labType) == normalized }
            .sorted { $0.collectedAt < $1.collectedAt }

        return VStack(alignment: .leading, spacing: 10) {
            metricChart(for: normalized, dataPoints: dataPoints)
            historyList(for: normalized, dataPoints: dataPoints)
        }
        .padding(.horizontal)
    }

    private func metricChart(for code: String, dataPoints: [LabResult]) -> some View {
        let latestRefLow = dataPoints.last?.refRangeLow ?? dataPoints.last?.effectiveRefRangeLow
        let latestRefHigh = dataPoints.last?.refRangeHigh ?? dataPoints.last?.effectiveRefRangeHigh
        let ref = (latestRefLow != nil && latestRefHigh != nil)
            ? (low: latestRefLow!, high: latestRefHigh!)
            : LabReferenceRanges.effectiveRange(for: code)
        let displayName = LabTrendCatalog.displayName(for: code)
        let unit = LabTrendCatalog.metric(for: code)?.defaultUnit ?? dataPoints.last?.unit ?? ""
        let regimen = activeRegimens.first

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayName)
                    .font(.headline)
                Spacer()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if dataPoints.isEmpty {
                VStack(spacing: 12) {
                    Text("暂无历史数据")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        addLabPreselectedCode = code
                        showAddLab = true
                    } label: {
                        Label("添加 \(LabTrendCatalog.chineseName(for: code)) 记录", systemImage: "plus")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.brandTeal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let chartWidth = max(320, CGFloat(dataPoints.count) * 64)
                ScrollView(.horizontal, showsIndicators: true) {
                    Chart {
                        ForEach(dataPoints, id: \.persistentModelID) { point in
                            LineMark(
                                x: .value("时间", chartXDate(for: point, regimen: regimen)),
                                y: .value("数值", point.value)
                            )
                            .foregroundStyle(AppTheme.brandTeal)

                            PointMark(
                                x: .value("时间", chartXDate(for: point, regimen: regimen)),
                                y: .value("数值", point.value)
                            )
                            .foregroundStyle(point.isOutOfRange ? AppTheme.riskRed : AppTheme.brandTeal)
                            .annotation(position: .top, spacing: 4) {
                                Text(formatValue(point.value))
                                    .font(.caption2)
                                    .foregroundStyle(point.isOutOfRange ? AppTheme.riskRed : .secondary)
                            }
                        }

                        if let lower = ref?.low {
                            RuleMark(y: .value("下限", lower))
                                .foregroundStyle(AppTheme.riskGreen.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        }

                        if let upper = ref?.high, upper < 500 {
                            RuleMark(y: .value("上限", upper))
                                .foregroundStyle(AppTheme.riskRed.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        }
                    }
                    .frame(width: chartWidth, height: 220)
                    .chartYAxis { AxisMarks(position: .leading) }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            if settings.alignLabsToCycle, let regimen, let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(cycleLabel(for: date, regimen: regimen))
                                        .font(.caption2)
                                }
                            } else if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date, format: .dateTime.month().day())
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
                Text("左右滑动查看各次数值")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let ref {
                Text("参考范围：\(ref.low, format: .number.precision(.fractionLength(1))) – \(ref.high, format: .number.precision(.fractionLength(1)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .companionCard()
    }

    private func historyList(for code: String, dataPoints: [LabResult]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !dataPoints.isEmpty {
                Text("历史记录")
                    .font(.subheadline.bold())
                    .padding(.leading, 4)

                ForEach(dataPoints.reversed(), id: \.persistentModelID) { point in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.collectedAt, format: .dateTime.year().month().day())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if point.isManualEntry {
                                Text("手动")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.brandIndigo.opacity(0.15))
                                    .foregroundStyle(AppTheme.brandIndigo)
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                        Text(formatValue(point.value))
                            .font(.subheadline.bold())
                            .foregroundStyle(point.isOutOfRange ? AppTheme.riskRed : .primary)
                        Text(point.unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func chartXDate(for point: LabResult, regimen: RegimenInstance?) -> Date {
        point.collectedAt
    }

    private func cycleLabel(for date: Date, regimen: RegimenInstance) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: regimen.startDate), to: cal.startOfDay(for: date)).day ?? 0
        guard days >= 0, regimen.cycleDays > 0 else {
            return date.formatted(.dateTime.month().day())
        }
        let cycle = days / regimen.cycleDays + 1
        let day = days % regimen.cycleDays + 1
        return "C\(cycle)D\(day)"
    }

    private func formatValue(_ v: Double) -> String {
        v == floor(v) ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private func emptyTrendsPlaceholder(title: String, message: String) -> some View {
        ContentUnavailableView(title, systemImage: "chart.line.uptrend.xyaxis", description: Text(message))
            .padding(.top, 40)
    }
}

private extension LabTrendCatalog {
    static func shortLabel(for code: String) -> String {
        metric(for: code)?.shortLabel ?? code
    }
}

#Preview {
    NavigationStack {
        LabTrendsView()
    }
    .modelContainer(CompanionModelContainer.make(inMemory: true))
}
