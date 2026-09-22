import SwiftUI

struct DoctorAuditInboxView: View {
    @State private var mailbox = DoctorAuditMailboxStore.shared
    @State private var accountStore = AccountStore.shared
    @State private var doctorStore = DoctorCertificationStore.shared

    private var accountId: String? { accountStore.currentUser?.id }

    private var items: [AuditMailMessage] {
        guard let accountId else { return [] }
        return mailbox.messages(for: accountId)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "暂无邮件",
                    systemImage: "envelope",
                    description: Text("认证申请与审核结果会显示在这里")
                )
            } else {
                List(items) { item in
                    NavigationLink {
                        DoctorAuditMailDetailView(message: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.subject)
                                    .font(.subheadline.bold())
                                if !item.isRead {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            Text(item.createdAt, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("审核邮箱")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let accountId else { return }
            mailbox.markAllRead(accountId: accountId)
        }
        #if DEBUG
        .safeAreaInset(edge: .bottom) {
            debugAuditBar
        }
        #endif
    }

    #if DEBUG
    private var debugAuditBar: some View {
        VStack(spacing: 8) {
            Text("开发测试：模拟平台审核")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Button("模拟通过") {
                    guard let accountId else { return }
                    doctorStore.markApproved(accountId: accountId)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.riskGreen)

                Button("模拟拒绝") {
                    guard let accountId else { return }
                    doctorStore.markRejected(accountId: accountId, reason: "证件信息不完整，请重新上传医师资格证。")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    #endif
}

private struct DoctorAuditMailDetailView: View {
    let message: AuditMailMessage
    @State private var mailbox = DoctorAuditMailboxStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(message.subject)
                    .font(.title3.bold())
                Text(message.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.body)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("邮件详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            mailbox.markRead(id: message.id)
        }
    }
}

#Preview {
    NavigationStack {
        DoctorAuditInboxView()
    }
}
