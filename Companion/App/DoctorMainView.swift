import SwiftUI

private enum DoctorHomeRoute: Hashable {
    case inbox
    case doctorChat(String)
    case certification
    case auditMail
}

struct DoctorMainView: View {
    @State private var accountStore = AccountStore.shared
    @State private var doctorStore = DoctorCertificationStore.shared
    @State private var mailbox = DoctorAuditMailboxStore.shared
    @State private var deepLink = ConsultationDeepLink.shared
    @State private var path = NavigationPath()
    @State private var showCertSheet = false

    private var accountId: String? { accountStore.currentUser?.id }

    private var unreadMail: Int {
        guard let accountId else { return 0 }
        return mailbox.unreadCount(for: accountId)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    answerPatientCard
                    if doctorStore.isPendingReview {
                        pendingBanner
                    }
                    if doctorStore.certification?.status == .rejected,
                       let reason = doctorStore.certification?.rejectionReason {
                        rejectedBanner(reason: reason)
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("医生工作台")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(DoctorHomeRoute.auditMail)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "envelope.fill")
                            if unreadMail > 0 {
                                Text("\(min(unreadMail, 99))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .accessibilityLabel("审核邮箱")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if doctorStore.certification != nil {
                            Button("查看认证信息") {
                                path.append(DoctorHomeRoute.certification)
                            }
                        }
                        Button("退出登录", role: .destructive) {
                            accountStore.logout()
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .navigationDestination(for: DoctorHomeRoute.self) { route in
                switch route {
                case .inbox:
                    DoctorInboxView()
                case .doctorChat(let id):
                    DoctorActiveChatView(consultationId: id)
                case .certification:
                    DoctorCertificationView(onSubmitted: {
                        path.removeLast(path.count)
                    })
                case .auditMail:
                    DoctorAuditInboxView()
                }
            }
        }
        .onAppear {
            _ = doctorStore.changeToken
            _ = mailbox.changeToken
            presentCertIfNeeded()
            openDoctorChatIfNeeded()
        }
        .onChange(of: doctorStore.changeToken) { _, _ in
            presentCertIfNeeded()
        }
        .onChange(of: deepLink.pendingDoctorChatId) { _, _ in
            openDoctorChatIfNeeded()
        }
        .sheet(isPresented: $showCertSheet) {
            NavigationStack {
                DoctorCertificationView(onSubmitted: {
                    showCertSheet = false
                })
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("您好，\(doctorStore.certification?.realName ?? accountStore.currentUser?.email ?? "医生")")
                .font(.title3.bold())
            if doctorStore.isApprovedDoctor {
                Label("已通过认证，可接诊回复", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(AppTheme.riskGreen)
                    .font(.subheadline)
            } else if doctorStore.isPendingReview {
                Label("身份审核中", systemImage: "clock.fill")
                    .foregroundStyle(AppTheme.riskYellow)
                    .font(.subheadline)
            } else {
                Text("请先完成医生认证，审核通过后即可接诊。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .companionCard()
    }

    private var answerPatientCard: some View {
        Button {
            path.append(DoctorHomeRoute.inbox)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(AppTheme.brandTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text("回答患者问题")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(doctorStore.isApprovedDoctor
                         ? "查看待接诊与进行中的咨询"
                         : "可查看患者提问，审核通过后可回复")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .companionCard()
        }
        .buttonStyle(.plain)
    }

    private var pendingBanner: some View {
        Label("正在审核身份中，暂无法接诊回复。审核结果将发送至右上角邮箱。", systemImage: "info.circle.fill")
            .font(.footnote)
            .foregroundStyle(AppTheme.brandIndigo)
            .frame(maxWidth: .infinity, alignment: .leading)
            .companionCard()
    }

    private func rejectedBanner(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("认证未通过：\(reason)")
                .font(.footnote)
                .foregroundStyle(AppTheme.riskRed)
            Button("重新提交认证") {
                showCertSheet = true
            }
            .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .companionCard()
    }

    private func presentCertIfNeeded() {
        guard doctorStore.certification == nil
            || doctorStore.certification?.status == .rejected else { return }
        if !showCertSheet, path.isEmpty {
            showCertSheet = true
        }
    }

    private func openDoctorChatIfNeeded() {
        guard let id = deepLink.consumePendingDoctorChatId() else { return }
        path.append(DoctorHomeRoute.doctorChat(id))
    }
}

#Preview {
    DoctorMainView()
}
