import SwiftUI
import SwiftData

struct HealthTasksView: View {
    @Query(sort: \SymptomLog.date, order: .reverse) private var symptomLogs: [SymptomLog]

    @State private var beans = HealthBeansStore.shared
    @State private var toastMessage: String?
    @State private var showNoAdAlert = false
    @State private var showShareSheet = false
    @State private var showShareChannels = false
    @State private var showQuiz = false
    @State private var showHelp = false

    private var todayLog: SymptomLog? {
        symptomLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var shareText: String {
        TodayCheckInShareBuilder.build(log: todayLog)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                balanceCard
                taskList
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("健康豆任务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHelp = true
                } label: {
                    Text("❓")
                        .font(.body)
                        .accessibilityLabel("健康豆使用说明")
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                HealthBeansHelpView()
            }
        }
        .alert("暂时没有广告", isPresented: $showNoAdAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("广告功能即将上线，完成后即可领取健康豆。")
        }
        .confirmationDialog("分享今日打卡", isPresented: $showShareChannels, titleVisibility: .visible) {
            Button("微信") { shareVia(.wechat) }
            Button("QQ") { shareVia(.qq) }
            Button("WhatsApp") { shareVia(.whatsapp) }
            Button("更多分享…") { showShareSheet = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("分享成功后可获得 \(HealthBeansStore.shareReward) 健康豆（每日一次）")
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            awardShareIfNeeded()
        }) {
            ShareSheet(items: [shareText])
        }
        .sheet(isPresented: $showQuiz) {
            NavigationStack {
                HealthQuizView()
            }
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .onAppear {
            beans.rollDayIfNeeded()
            beans.rollWeekIfNeeded()
            beans.rollMonthIfNeeded()
            beans.syncTodayCheckInIntoWeekIfNeeded()
        }
    }

    private var balanceCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("我的健康豆")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(beans.balance)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer()
            NavigationLink {
                HealthBeansRechargeView()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("充值")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.brandTeal)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .companionCard()
    }

    private var taskList: some View {
        VStack(spacing: 12) {
            Text("每日任务")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            checkInTaskCard

            taskRow(
                icon: "play.rectangle.fill",
                iconColor: AppTheme.brandIndigo,
                title: "看广告领豆",
                subtitle: "每次 \(HealthBeansStore.adReward) 豆 · 今日还可 \(beans.adsRemainingToday)/\(HealthBeansStore.adDailyLimit) 次",
                trailing: beans.adsRemainingToday == 0 ? .done : .action("看广告"),
                action: { showNoAdAlert = true }
            )

            taskRow(
                icon: "square.and.arrow.up",
                iconColor: .purple,
                title: "分享今日打卡",
                subtitle: beans.hasSharedToday
                    ? "今日已分享"
                    : "分享到微信 / QQ / WhatsApp，得 \(HealthBeansStore.shareReward) 豆",
                trailing: beans.hasSharedToday ? .done : .action("分享"),
                action: {
                    if beans.hasSharedToday {
                        showToast("今日已领取分享奖励")
                    } else {
                        showShareChannels = true
                    }
                }
            )

            taskRow(
                icon: "questionmark.circle.fill",
                iconColor: .orange,
                title: "每日健康测验",
                subtitle: "答对一题 \(HealthBeansStore.quizRewardPerCorrect) 豆 · 已答对 \(beans.quizCorrectToday)/\(HealthBeansStore.quizDailyLimit) 题",
                trailing: beans.quizRemainingToday == 0 ? .done : .action("答题"),
                action: { showQuiz = true }
            )
        }
    }

    private var checkInTaskCard: some View {
        Button(action: claimCheckIn) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.brandTeal)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("每日签到")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("\(beans.weekCheckInCount)/\(HealthBeansStore.weekCheckInTarget)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(AppTheme.brandTeal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppTheme.brandTeal.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        Text(checkInSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    if beans.hasCheckedInToday {
                        Text("已完成")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.riskGreen)
                    } else {
                        Text("签到")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.brandTeal)
                            .clipShape(Capsule())
                    }
                }

                weekCheckInDots

                Text("本周签到满 5 天额外 +10，满 7 天再额外 +10")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .companionCard()
        }
        .buttonStyle(.plain)
    }

    private var checkInSubtitle: String {
        let reward = beans.effectiveCheckInReward
        if beans.hasCheckedInToday {
            return "今日已签到 · 本周已签 \(beans.weekCheckInCount) 天"
        }
        if beans.hasActiveMonthCard {
            return "月卡权益：签到领取 \(reward) 健康豆"
        }
        return "签到领取 \(reward) 健康豆"
    }

    private var weekCheckInDots: some View {
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        let flags = beans.weekCheckInFlags
        return HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 4) {
                    Circle()
                        .fill(flags[index] ? AppTheme.brandTeal : Color.secondary.opacity(0.2))
                        .frame(width: 22, height: 22)
                        .overlay {
                            if flags[index] {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    Text(labels[index])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private enum TrailingStyle {
        case action(String)
        case done
    }

    private func taskRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        trailing: TrailingStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                switch trailing {
                case .done:
                    Text("已完成")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.riskGreen)
                case .action(let label):
                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.brandTeal)
                        .clipShape(Capsule())
                }
            }
            .companionCard()
        }
        .buttonStyle(.plain)
    }

    private func claimCheckIn() {
        guard let result = beans.claimDailyCheckIn() else {
            showToast("今日已签到")
            return
        }
        var message = "签到成功，+\(result.baseReward) 健康豆（\(result.weekCount)/\(HealthBeansStore.weekCheckInTarget)）"
        if result.weekBonus > 0 {
            message += "，周奖励 +\(result.weekBonus)"
        }
        showToast(message)
    }

    private enum ShareChannel {
        case wechat, qq, whatsapp
    }

    private func shareVia(_ channel: ShareChannel) {
        let text = shareText
        let application = UIApplication.shared

        switch channel {
        case .whatsapp:
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "whatsapp://send?text=\(encoded)"), application.canOpenURL(url) {
                application.open(url) { success in
                    if success { awardShareIfNeeded() }
                    else { showShareSheet = true }
                }
                return
            }
            showToast("未检测到 WhatsApp，改为系统分享")
            showShareSheet = true
        case .wechat:
            if let url = URL(string: "weixin://"), application.canOpenURL(url) {
                // 无 SDK 时无法预填文案：先复制再打开微信
                UIPasteboard.general.string = text
                application.open(url) { success in
                    if success {
                        let reward = beans.claimShareReward()
                        if let reward {
                            showToast("已复制内容并打开微信，+\(reward) 健康豆")
                        } else {
                            showToast("已复制打卡内容，粘贴后即可发送")
                        }
                    } else {
                        showShareSheet = true
                    }
                }
                return
            }
            showToast("未检测到微信，改为系统分享")
            showShareSheet = true
        case .qq:
            if let url = URL(string: "mqq://"), application.canOpenURL(url) {
                UIPasteboard.general.string = text
                application.open(url) { success in
                    if success {
                        let reward = beans.claimShareReward()
                        if let reward {
                            showToast("已复制内容并打开 QQ，+\(reward) 健康豆")
                        } else {
                            showToast("已复制打卡内容，粘贴后即可发送")
                        }
                    } else {
                        showShareSheet = true
                    }
                }
                return
            }
            showToast("未检测到 QQ，改为系统分享")
            showShareSheet = true
        }
    }

    private func awardShareIfNeeded() {
        if let reward = beans.claimShareReward() {
            showToast("分享成功，+\(reward) 健康豆")
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthTasksView()
    }
    .modelContainer(CompanionModelContainer.make(inMemory: true))
}
