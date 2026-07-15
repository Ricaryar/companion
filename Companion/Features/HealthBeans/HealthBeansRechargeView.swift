import SwiftUI

struct HealthBeansRechargeView: View {
    @State private var beans = HealthBeansStore.shared
    @State private var pendingPackage: HealthBeanRechargePackage?
    @State private var showConfirmPackage = false
    @State private var showConfirmMonthCard = false
    @State private var toastMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                rateHint
                packagesSection
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("充值健康豆")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认充值", isPresented: $showConfirmPackage) {
            Button("取消", role: .cancel) { pendingPackage = nil }
            Button("确认支付") {
                if let pkg = pendingPackage {
                    let result = beans.completeRecharge(package: pkg)
                    var parts: [String] = ["到账 \(result.totalBeans) 健康豆"]
                    if result.bonus > 0 {
                        parts.append("含本价位首充赠送 \(result.bonus)")
                    }
                    if result.followUpCards > 0 {
                        parts.append("追问卡 +\(result.followUpCards)")
                    }
                    showToast(parts.joined(separator: "，"))
                }
                pendingPackage = nil
            }
        } message: {
            if let pkg = pendingPackage {
                packageConfirmMessage(pkg)
            }
        }
        .alert("确认购买超值月卡", isPresented: $showConfirmMonthCard) {
            Button("取消", role: .cancel) {}
            Button("确认支付") {
                let result = beans.purchaseMonthCard()
                if result.alreadyActive {
                    showToast("本月月卡已生效")
                } else {
                    showToast("月卡已开通，追问卡 +\(result.followUpCards)")
                }
            }
        } message: {
            Text("支付 ¥9.9，本月享：每日签到送 20 健康豆、提问积分八折，并赠送 3 张免费追问卡。\n（演示到账，正式版将接入 App Store 支付）")
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.brandGraphite.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            beans.rollMonthIfNeeded()
        }
    }

    private func packageConfirmMessage(_ pkg: HealthBeanRechargePackage) -> Text {
        let eligible = pkg.firstPurchaseBonus > 0 && !beans.hasClaimedFirstBonus(forPackageId: pkg.id)
        let bonus = eligible ? pkg.firstPurchaseBonus : 0
        let total = pkg.beans + bonus
        var lines: [String] = []
        if bonus > 0 {
            lines.append("支付 ¥\(pkg.priceYuan)，获得 \(pkg.beans) 健康豆 + 本价位首充赠送 \(bonus)，合计 \(total) 豆。")
        } else {
            lines.append("支付 ¥\(pkg.priceYuan)，获得 \(pkg.beans) 健康豆。")
        }
        if pkg.followUpCards > 0 {
            lines.append("另赠可追问 \(pkg.followUpCards) 次。")
        }
        lines.append("（演示到账，正式版将接入 App Store 支付）")
        return Text(lines.joined(separator: "\n"))
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("当前余额")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(beans.balance)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                if beans.followUpCards > 0 || beans.hasActiveMonthCard {
                    Text(headerPerkLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if beans.hasActiveMonthCard {
                Text("月卡生效中")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.brandTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.brandTeal.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .companionCard()
    }

    private var headerPerkLine: String {
        var parts: [String] = []
        if beans.hasActiveMonthCard {
            parts.append("提问八折")
        }
        if beans.followUpCards > 0 {
            parts.append("追问卡 \(beans.followUpCards) 张")
        }
        return parts.joined(separator: " · ")
    }

    private var rateHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppTheme.brandTeal)
            Text("充值比例 1 元 = \(HealthBeansStore.rechargeBeansPerYuan) 健康豆")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var packagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择充值套餐")
                .font(.headline)

            monthCardRow

            ForEach(HealthBeanRechargePackage.all) { pkg in
                packageRow(pkg)
            }
        }
    }

    private var monthCardRow: some View {
        Button {
            if beans.hasActiveMonthCard {
                showToast("本月月卡已生效")
            } else {
                showConfirmMonthCard = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("超值月卡")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("优惠")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        benefitLine("每日签到赠送 20 健康豆")
                        benefitLine("本月提问积分可打八折")
                        benefitLine("赠送 3 张免费追问卡")
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("¥9.9")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(beans.hasActiveMonthCard ? Color.secondary : AppTheme.brandTeal)
                            .clipShape(Capsule())
                        if beans.hasActiveMonthCard {
                            Text("已开通")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.riskGreen)
                        }
                    }
                }
            }
            .companionCard()
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.45), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func benefitLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.brandTeal)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
    }

    private func packageRow(_ pkg: HealthBeanRechargePackage) -> some View {
        let showBonus = pkg.firstPurchaseBonus > 0 && !beans.hasClaimedFirstBonus(forPackageId: pkg.id)
        return Button {
            pendingPackage = pkg
            showConfirmPackage = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("\(pkg.beans) 健康豆")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        if showBonus, let badge = pkg.badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    if let subtitle = pkg.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if showBonus {
                        Text("到账 \(pkg.beans + pkg.firstPurchaseBonus) 豆（含本价位首充赠送 \(pkg.firstPurchaseBonus)）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if pkg.firstPurchaseBonus > 0 {
                        Text("本价位本月已享受过首充赠送")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("按 1:\(HealthBeansStore.rechargeBeansPerYuan) 兑换")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("¥\(pkg.priceYuan)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.brandTeal)
                    .clipShape(Capsule())
            }
            .companionCard()
        }
        .buttonStyle(.plain)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthBeansRechargeView()
    }
}
