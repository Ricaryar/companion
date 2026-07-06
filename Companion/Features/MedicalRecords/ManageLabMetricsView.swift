import SwiftUI

struct ManageLabMetricsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        List {
            Section {
                Text("勾选要在趋势页追踪的项目，可按分类选择。至少保留一项。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(TrendLabCategory.allCases, id: \.self) { category in
                let metrics = LabTrendCatalog.all.filter { $0.category == category }
                if !metrics.isEmpty {
                    Section(category.rawValue) {
                        ForEach(metrics) { metric in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric.displayName)
                                        .font(.subheadline)
                                    if !metric.defaultUnit.isEmpty {
                                        Text(metric.defaultUnit)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if settings.isTrackingLabMetric(metric.code) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.brandTeal)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settings.toggleLabMetric(metric.code)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("管理趋势项目")
    }
}

#Preview {
    NavigationStack {
        ManageLabMetricsView()
    }
}
