import SwiftUI

/// 真实用药社区首页：分类、搜索、列表、发布入口
struct MedicationShareCommunityView: View {
    @State private var store = MedicationShareStore.shared
    @State private var searchText = ""
    @State private var selectedCategory: MedicationDiseaseCategory?
    @State private var showPublish = false
    @State private var showWallet = false
    @State private var showInbox = false

    private var list: [MedicationShare] {
        store.filteredCommunity(category: selectedCategory, search: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryBar
            if list.isEmpty {
                ContentUnavailableView(
                    "暂无相关分享",
                    systemImage: "pills",
                    description: Text(searchText.isEmpty ? "成为第一个分享真实用药经验的人" : "试试更换关键词或分类")
                )
            } else {
                List(list) { item in
                    NavigationLink {
                        MedicationShareDetailView(shareId: item.id)
                    } label: {
                        shareRow(item)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("真实用药")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索药品、疾病、靶向药…")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showWallet = true
                } label: {
                    Label(
                        String(format: "¥%.0f", store.cashBalanceYuan),
                        systemImage: "yensign.circle"
                    )
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInbox = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "envelope.fill")
                        if store.unreadNoticeCount > 0 {
                            Text("\(min(store.unreadNoticeCount, 99))")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .offset(x: 8, y: -8)
                        }
                    }
                    .accessibilityLabel(
                        store.unreadNoticeCount > 0
                        ? "通知，\(store.unreadNoticeCount)条未读"
                        : "通知"
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showPublish = true
            } label: {
                Text("分享我的用药")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.brandTeal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showPublish) {
            NavigationStack {
                MedicationShareRulesView {
                    showPublish = false
                }
            }
        }
        .sheet(isPresented: $showWallet) {
            NavigationStack {
                MedicationShareWalletView()
            }
        }
        .sheet(isPresented: $showInbox) {
            NavigationStack {
                MedicationShareInboxView()
            }
        }
        .onAppear { _ = store.changeToken }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "全部", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(MedicationDiseaseCategory.allCases) { category in
                    categoryChip(title: category.rawValue, selected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func categoryChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? AppTheme.brandTeal : AppTheme.cardBackground)
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shareRow(_ item: MedicationShare) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if item.isHighValue {
                    Text("高价值")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            Text(item.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(item.categoryPathText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            HStack(spacing: 12) {
                Label("\(item.viewCount)", systemImage: "eye")
                Label("\(item.usefulCount)", systemImage: "hand.thumbsup")
                Label("\(item.comments.count)", systemImage: "bubble.left")
                Spacer()
                Text(item.authorName)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MedicationShareCommunityView()
    }
}
