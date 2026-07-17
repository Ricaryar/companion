import SwiftUI

/// 真实用药站内信：审核、提现等通知入口
struct MedicationShareInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = MedicationShareStore.shared

    var body: some View {
        Group {
            if store.notices.isEmpty {
                ContentUnavailableView(
                    "暂无通知",
                    systemImage: "envelope",
                    description: Text("审核结果、提现进度等消息会出现在这里")
                )
            } else {
                List {
                    ForEach(store.notices) { notice in
                        Button {
                            store.markNoticeRead(id: notice.id)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(notice.isRead ? Color.clear : AppTheme.brandTeal)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(notice.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(notice.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Text(notice.createdAt, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if store.unreadNoticeCount > 0 {
                    Button("全部已读") {
                        store.markAllNoticesRead()
                    }
                }
            }
        }
        .onAppear { _ = store.changeToken }
    }
}

#Preview {
    NavigationStack {
        MedicationShareInboxView()
    }
}
