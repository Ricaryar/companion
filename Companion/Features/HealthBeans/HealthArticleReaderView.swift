import SwiftUI

struct HealthArticleListView: View {
    @State private var beans = HealthBeansStore.shared
    @State private var medStore = MedicationShareStore.shared
    @Environment(\.dismiss) private var dismiss

    private var articles: [HealthArticle] {
        HealthArticleBank.todayArticles(limit: HealthBeansStore.articleDailyLimit)
    }

    private var scienceShares: [MedicationShare] {
        medStore.scienceTaskShares
    }

    var body: some View {
        List {
            Section {
                Text("阅读满 \(HealthBeansStore.articleRequiredSeconds) 秒可领取 \(HealthBeansStore.articleReward) 健康豆 · 今日还可 \(beans.articlesRemainingToday)/\(HealthBeansStore.articleDailyLimit) 篇")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !scienceShares.isEmpty {
                Section("真实用药 · 科普投放") {
                    Text("常见药或热度未达标的激励类分享会投放至此，阅读同样可领健康豆。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(scienceShares.prefix(8)) { share in
                        NavigationLink {
                            MedicationShareScienceReaderView(shareId: share.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(share.title)
                                    .font(.subheadline.bold())
                                Text(share.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(share.categoryPathText)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 2)
                        }
                        .disabled(beans.articlesRemainingToday == 0)
                    }
                }
            }

            Section("今日科普") {
                ForEach(articles) { article in
                    NavigationLink {
                        HealthArticleReaderView(article: article)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title)
                                .font(.subheadline.bold())
                            Text(article.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                    .disabled(beans.articlesRemainingToday == 0)
                }
            }
        }
        .navigationTitle("科普阅读")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            beans.rollDayIfNeeded()
            _ = medStore.changeToken
        }
    }
}

/// 科普区真实用药分享阅读（计时领健康豆）
struct MedicationShareScienceReaderView: View {
    let shareId: String

    @State private var store = MedicationShareStore.shared
    @State private var beans = HealthBeansStore.shared
    @State private var elapsed = 0
    @State private var claimed = false
    @State private var toast: String?

    private var share: MedicationShare? { store.share(id: shareId) }

    private var remaining: Int {
        max(0, HealthBeansStore.articleRequiredSeconds - elapsed)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let share {
                    Text(share.title)
                        .font(.title3.bold())
                    Text(share.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(share.body)
                        .font(.body)

                    NavigationLink {
                        PublicQALibraryView()
                    } label: {
                        Label("对这种药有疑问？去提问咨询医生", systemImage: "stethoscope")
                    }
                    .buttonStyle(.bordered)

                    if claimed {
                        Text("已领取本篇奖励")
                            .foregroundStyle(AppTheme.riskGreen)
                    } else if beans.articlesRemainingToday == 0 {
                        Text("今日阅读奖励已达上限")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(remaining > 0
                             ? "请继续阅读，\(remaining) 秒后可领取奖励"
                             : "已达到领取条件")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if remaining == 0 {
                            Button("领取 \(HealthBeansStore.articleReward) 健康豆") {
                                if let reward = beans.claimArticleReward(articleTitle: share.title) {
                                    claimed = true
                                    toast = "+\(reward) 健康豆"
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.brandTeal)
                        }
                    }
                } else {
                    Text("内容不存在")
                }
            }
            .padding()
        }
        .navigationTitle("科普分享")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.markViewed(id: shareId) }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if elapsed < HealthBeansStore.articleRequiredSeconds {
                elapsed += 1
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.brandGraphite.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
        }
    }
}

struct HealthArticleReaderView: View {
    let article: HealthArticle

    @State private var beans = HealthBeansStore.shared
    @State private var elapsed = 0
    @State private var claimed = false
    @State private var toast: String?
    @Environment(\.dismiss) private var dismiss

    private var remaining: Int {
        max(0, HealthBeansStore.articleRequiredSeconds - elapsed)
    }

    private var canClaim: Bool {
        remaining == 0 && !claimed && beans.articlesRemainingToday > 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title3.bold())
                Text(article.body)
                    .font(.body)
                    .foregroundStyle(.primary)

                if claimed {
                    Text("已领取本篇奖励")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.riskGreen)
                } else if beans.articlesRemainingToday == 0 {
                    Text("今日阅读奖励已达上限")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(remaining > 0
                         ? "请继续阅读，\(remaining) 秒后可领取奖励"
                         : "阅读完成，可领取 \(HealthBeansStore.articleReward) 健康豆")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.brandTeal)
                }

                DisclaimerFooter()
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("科普文章")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                claim()
            } label: {
                Text(claimButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.brandTeal)
            .disabled(!canClaim)
            .padding()
            .background(.ultraThinMaterial)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard !claimed, beans.articlesRemainingToday > 0 else { return }
            if elapsed < HealthBeansStore.articleRequiredSeconds {
                elapsed += 1
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(AppTheme.brandGraphite.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 80)
            }
        }
    }

    private var claimButtonTitle: String {
        if claimed { return "已领取" }
        if remaining > 0 { return "阅读中（\(remaining)s）" }
        return "领取 \(HealthBeansStore.articleReward) 健康豆"
    }

    private func claim() {
        guard canClaim else { return }
        if let reward = beans.claimArticleReward(articleTitle: article.title) {
            claimed = true
            toast = "+\(reward) 健康豆"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                toast = nil
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthArticleListView()
    }
}
