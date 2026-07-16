import SwiftUI

struct HealthArticleListView: View {
    @State private var beans = HealthBeansStore.shared
    @Environment(\.dismiss) private var dismiss

    private var articles: [HealthArticle] {
        HealthArticleBank.todayArticles(limit: HealthBeansStore.articleDailyLimit)
    }

    var body: some View {
        List {
            Section {
                Text("阅读满 \(HealthBeansStore.articleRequiredSeconds) 秒可领取 \(HealthBeansStore.articleReward) 健康豆 · 今日还可 \(beans.articlesRemainingToday)/\(HealthBeansStore.articleDailyLimit) 篇")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .onAppear { beans.rollDayIfNeeded() }
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
