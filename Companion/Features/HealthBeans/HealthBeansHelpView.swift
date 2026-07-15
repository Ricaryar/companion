import SwiftUI

struct HealthBeansHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introSection
                sectionCard(title: "一、健康豆可以用来做什么？") {
                    usageTable
                    tipBox
                }
                sectionCard(title: "二、如何赚取健康豆？") {
                    Text("每天通过完成任务获取健康豆，每天上限 160 豆（签到连续奖励不受此限制）。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                sectionCard(title: "三、健康豆会过期吗？") {
                    VStack(alignment: .leading, spacing: 10) {
                        expireRow(title: "通过做任务获得的健康豆", detail: "长期有效，不会清零（如有调整将提前 30 天公告）。")
                        expireRow(title: "通过充值购买的健康豆", detail: "永久有效，不过期。")
                        expireRow(title: "月卡赠送的额外健康豆", detail: "当日未领取则于次日清零，不可补领。")
                    }
                }
                sectionCard(title: "四、常见问题") {
                    VStack(alignment: .leading, spacing: 14) {
                        faqItem(
                            q: "健康豆可以转赠给家人或好友吗？",
                            a: "当前暂不支持转赠功能。您可以帮家人完成每日任务、累积健康豆后，使用自己的账号代为提问。"
                        )
                        faqItem(
                            q: "健康豆可以兑换成现金吗？",
                            a: "健康豆仅限在 App 内使用，不可提现或兑换现金。"
                        )
                        faqItem(
                            q: "充值后可以退款吗？",
                            a: "虚拟商品一经充值成功，不支持退款。如有疑问请联系客服。"
                        )
                    }
                }
                sectionCard(title: "五、温馨提醒") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("健康豆的初衷，是鼓励您每天花几分钟关注自己的身体状况。")
                        Text("遇到健康问题请及时咨询医生，危急情况请立即拨打 120 或前往就近医院就诊。")
                        Text("本平台咨询建议仅供参考，不能替代线下医疗诊断。")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("健康豆使用说明")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("健康豆使用说明")
                .font(.title3.bold())
            Text("健康豆是您在「\(CopyStrings.appNameZH)」App 里使用的专属虚拟积分。您的每一次签到、每一次学习，都会变成实实在在的健康豆，帮您随时发起咨询，守护自己和家人的健康。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .companionCard()
    }

    private var usageTable: some View {
        VStack(spacing: 0) {
            usageHeader
            Divider()
            usageRow(use: "发起一次图文咨询", cost: "150豆/次", note: "向平台认证医生发起一对一健康咨询")
            Divider()
            usageRow(use: "追加提问（第2次起）", cost: "30豆/次", note: "医生回复后的 24 小时内，可追加提问")
        }
        .background(Color(.tertiarySystemFill).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var usageHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("用途")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("所需健康豆")
                .frame(width: 72, alignment: .leading)
            Text("说明")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(10)
    }

    private func usageRow(use: String, cost: String, note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(use)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(cost)
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(AppTheme.brandTeal)
            Text(note)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(10)
    }

    private var tipBox: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text("小提示：如果您购买了「健康守护卡」月卡（9.9元/月），每次咨询仅需 120豆（8折优惠），并可获赠额外健康豆以及每月 3 张免费追问券。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.top, 4)
    }

    private func expireRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func faqItem(q: String, a: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Q：\(q)")
                .font(.subheadline.bold())
            Text("A：\(a)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .companionCard()
    }
}

#Preview {
    NavigationStack {
        HealthBeansHelpView()
    }
}
