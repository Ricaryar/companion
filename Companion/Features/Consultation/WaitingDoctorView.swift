import SwiftUI

struct WaitingDoctorView: View {
    let consultationId: String
    @Binding var path: NavigationPath
    @State private var store = ConsultationStore.shared
    @State private var showCancelConfirm = false
    @State private var toast: String?

    private var item: Consultation? {
        store.consultation(id: consultationId)
    }

    var body: some View {
        Group {
            if let item {
                if item.status == .active || item.status == .closed {
                    Color.clear.onAppear {
                        replaceWithChat()
                    }
                } else if item.status == .cancelled {
                    cancelledView
                } else {
                    waitingContent(item)
                }
            } else {
                ContentUnavailableView("未找到咨询", systemImage: "exclamationmark.triangle")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("等待接诊")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden((item?.status == .waiting) == true)
        .alert("取消咨询", isPresented: $showCancelConfirm) {
            Button("再等等", role: .cancel) {}
            Button("确认取消", role: .destructive) { cancel() }
        } message: {
            Text("取消后积分将全额退还。")
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            store.processTimeouts()
            if let latest = store.consultation(id: consultationId),
               latest.status == .active || latest.status == .closed {
                replaceWithChat()
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
                    .padding(.bottom, 24)
            }
        }
    }

    private func waitingContent(_ item: Consultation) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("⏳ 正在匹配医生…")
                .font(.title3.bold())
            Text("系统正在为您分配最合适的医生，请稍候，通常 5–15 分钟内会有医生接诊。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("─── 您的提问信息 ───")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                labeled("症状", item.symptom.rawValue)
                labeled("描述", item.detail)
            }
            .padding()
            .companionCard()
            .padding(.horizontal)

            Text("如需取消，请点击「取消咨询」（取消后积分将全额退还）")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("取消咨询", role: .destructive) {
                showCancelConfirm = true
            }

            Spacer()
        }
        .padding()
    }

    private var cancelledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("咨询已取消")
                .font(.title3.bold())
            Text("健康豆已退还（如适用）")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("返回大家问") {
                path = NavigationPath()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.brandTeal)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline)
        }
    }

    private func cancel() {
        let result = store.cancelWaiting(id: consultationId)
        switch result {
        case .success:
            toast = "已取消，积分已退还"
        case .failure(let error):
            toast = error.localizedDescription
        }
    }

    private func replaceWithChat() {
        // 去掉 waiting，换成 chat
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(QARoute.chat(consultationId))
    }
}
