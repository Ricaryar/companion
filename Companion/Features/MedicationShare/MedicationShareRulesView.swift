import SwiftUI

/// 发布前规则说明页
struct MedicationShareRulesView: View {
    var onFinished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var agreed = false
    @State private var goCategory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("💊 真实用药 · 分享须知")
                    .font(.title3.bold())

                Text("分享真实用药经历，帮助更多病友。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                groupTitle("现金激励范围")
                VStack(alignment: .leading, spacing: 8) {
                    bullet("✅ 肿瘤靶向药 / 免疫治疗药物", positive: true)
                    bullet("✅ 罕见病用药", positive: true)
                    bullet("✅ 刚上市的新药/临床试验药物", positive: true)
                    bullet("✅ 需长期服用的重症处方药", positive: true)
                    Divider().padding(.vertical, 4)
                    Text("❌ 常见非处方药（如布洛芬、999感冒灵、阿莫西林等）不纳入现金激励，但可投放至科普区，获得健康豆奖励")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .companionCard()

                groupTitle("分享奖励")
                VStack(alignment: .leading, spacing: 8) {
                    Text("审核通过并成功发布，即可获得")
                        .font(.subheadline)
                    Text("💰 \(MedicationShareRules.baseCashYuan)元 现金（满\(MedicationShareRules.withdrawMinYuan)元可提现）")
                        .font(.headline)
                        .foregroundStyle(AppTheme.brandTeal)
                    Text("浏览量 ≥ \(MedicationShareRules.viewBonusThreshold) 额外 +\(MedicationShareRules.viewBonusYuan) 元；「有用」≥ \(MedicationShareRules.usefulBonusThreshold) 再 +\(MedicationShareRules.usefulBonusYuan) 元。普通/常见药物分享不计现金。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .companionCard()

                Toggle(isOn: $agreed) {
                    Text("我已阅读并同意以上规则")
                        .font(.subheadline)
                }
                .tint(AppTheme.brandTeal)

                Button {
                    goCategory = true
                } label: {
                    Text("开始填写分享")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(agreed ? AppTheme.brandTeal : Color.secondary.opacity(0.35))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!agreed)
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("分享须知")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .navigationDestination(isPresented: $goCategory) {
            MedicationShareCategoryPickerView(onFinished: {
                onFinished?()
                dismiss()
            })
        }
    }

    private func groupTitle(_ text: String) -> some View {
        Text("─── \(text) ───")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    private func bullet(_ text: String, positive: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(positive ? .primary : .secondary)
    }
}
