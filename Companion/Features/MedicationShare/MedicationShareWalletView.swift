import SwiftUI

struct MedicationShareWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = MedicationShareStore.shared
    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("可提现余额")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "¥%.2f", store.cashBalanceYuan))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("分享审核成功发布后即可获得 \(MedicationShareRules.baseCashYuan) 元现金（普通药物分享不计）。满 \(MedicationShareRules.withdrawMinYuan) 元可提现。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                Button("申请提现") {
                    switch store.withdrawAll() {
                    case .success(let cents):
                        message = String(format: "已提交提现 ¥%.2f（演示环境模拟到账）", Double(cents) / 100)
                        showMessage = true
                    case .failure(let error):
                        message = error.localizedDescription
                        showMessage = true
                    }
                }
                .disabled(!store.canWithdraw)
            } footer: {
                Text("浏览量 ≥ \(MedicationShareRules.viewBonusThreshold) 额外 +\(MedicationShareRules.viewBonusYuan) 元；被「有用」≥ \(MedicationShareRules.usefulBonusThreshold) 再 +\(MedicationShareRules.usefulBonusYuan) 元。后续热度高还可继续补贴。")
            }

            Section("我的分享") {
                if store.myShares.isEmpty {
                    Text("暂无分享记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.myShares) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.bold())
                            Text(item.auditMessage ?? statusText(item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "累计奖励 ¥%.2f · 浏览 %d · 有用 %d", item.cashYuanEarned, item.viewCount, item.usefulCount))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("现金流水") {
                if store.cashLedger.isEmpty {
                    Text("暂无记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.cashLedger) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                Text(entry.date, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%@¥%.2f", entry.amountCents >= 0 ? "+" : "-", abs(Double(entry.amountCents) / 100)))
                                .foregroundStyle(entry.amountCents >= 0 ? AppTheme.riskGreen : .primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("分享奖金")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .alert("提示", isPresented: $showMessage) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func statusText(_ item: MedicationShare) -> String {
        switch item.status {
        case .pending: "审核中"
        case .approved: item.placement == .community && item.isHighValue ? "已发布（高价值）" : "已发布（社区+科普）"
        case .rejected: "未通过"
        }
    }
}
