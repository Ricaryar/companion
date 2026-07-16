import SwiftUI

struct HealthBeansLedgerView: View {
    @State private var beans = HealthBeansStore.shared

    var body: some View {
        Group {
            if beans.ledgerEntries.isEmpty {
                ContentUnavailableView(
                    "暂无流水记录",
                    systemImage: "list.bullet.rectangle",
                    description: Text("获得或消耗健康豆后，将在此显示明细。")
                )
            } else {
                List(beans.ledgerEntries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.subheadline.bold())
                            Text(entry.date, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("余额 \(entry.balanceAfter)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(amountText(entry.amount))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(entry.amount >= 0 ? AppTheme.riskGreen : AppTheme.riskRed)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("健康豆流水")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("当前余额")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(beans.balance)")
                        .font(.headline.monospacedDigit())
                }
            }
        }
    }

    private func amountText(_ amount: Int) -> String {
        amount >= 0 ? "+\(amount)" : "\(amount)"
    }
}

#Preview {
    NavigationStack {
        HealthBeansLedgerView()
    }
}
