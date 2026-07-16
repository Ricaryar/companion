import SwiftUI

struct ConsultationChatView: View {
    let consultationId: String
    @Binding var path: NavigationPath
    @State private var store = ConsultationStore.shared
    @State private var beans = HealthBeansStore.shared
    @State private var input = ""
    @State private var showFollowUpConfirm = false
    @State private var showEndConfirm = false
    @State private var showRating = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var now = Date()

    private var item: Consultation? {
        store.consultation(id: consultationId)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let item {
                doctorHeader(item)
                countdownBar(item)
                messageList(item)
                inputBar(item)
            } else {
                ContentUnavailableView("未找到对话", systemImage: "bubble.left")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("咨询对话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if item?.status == .active {
                    Button("结束对话") {
                        showEndConfirm = true
                    }
                    .foregroundStyle(AppTheme.riskRed)
                }
            }
        }
        .onAppear {
            store.markRead(id: consultationId)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
            store.processTimeouts()
        }
        .alert("确认追问", isPresented: $showFollowUpConfirm) {
            Button("取消", role: .cancel) {}
            Button("继续发送") { performSend() }
        } message: {
            Text("本次追问将消耗 \(ConsultationRules.followUpCost) 健康豆，是否继续？")
        }
        .alert("结束对话", isPresented: $showEndConfirm) {
            Button("再想想", role: .cancel) {}
            Button("确认结束", role: .destructive) { endDialog() }
        } message: {
            Text("结束后将无法继续追问，并将进入咨询评价。")
        }
        .alert("无法发送", isPresented: $showError) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showRating) {
            ConsultationRatingSheet(consultationId: consultationId) {
                showRating = false
            }
        }
    }

    @ViewBuilder
    private func doctorHeader(_ item: Consultation) -> some View {
        if let doctor = item.doctor, item.status != .waiting {
            HStack(spacing: 12) {
                Image(systemName: doctor.avatarSymbol)
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.brandTeal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(doctor.name) · \(doctor.title)")
                        .font(.subheadline.bold())
                    Text("\(doctor.hospital) · \(doctor.department)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("评分 \(String(format: "%.1f", doctor.rating))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(AppTheme.cardBackground)
        }
    }

    private func countdownBar(_ item: Consultation) -> some View {
        Group {
            if item.status == .closed {
                Text("对话已结束")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(.tertiarySystemFill))
            } else if item.status == .active, let remain = item.remainingDialogSeconds {
                Text(remain > 0 ? "剩余对话时间：\(formatHMS(remain))" : "对话已结束")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(remain > 0 ? AppTheme.brandTeal : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(AppTheme.brandTeal.opacity(0.08))
            }
        }
    }

    private func messageList(_ item: Consultation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(item.messages) { msg in
                        messageRow(msg, doctor: item.doctor)
                            .id(msg.id)
                    }
                }
                .padding()
            }
            .onChange(of: item.messages.count) { _, _ in
                if let last = item.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func messageRow(_ msg: ChatMessage, doctor: DoctorProfile?) -> some View {
        VStack(alignment: msg.sender == .user ? .trailing : .leading, spacing: 4) {
            HStack {
                if msg.sender == .user { Spacer(minLength: 40) }
                VStack(alignment: .leading, spacing: 6) {
                    if msg.sender == .doctor, let doctor {
                        Text("👨‍⚕️ \(doctor.name) \(doctor.title) · \(doctor.department)")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.brandTeal)
                        Text(doctor.hospital)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if msg.sender == .system {
                        Text("系统")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("我")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                    Text(msg.text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(msg.createdAt, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(bubbleColor(msg.sender))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if msg.sender != .user { Spacer(minLength: 40) }
            }
        }
    }

    private func bubbleColor(_ sender: ChatSender) -> Color {
        switch sender {
        case .user: AppTheme.brandTeal.opacity(0.15)
        case .doctor: AppTheme.cardBackground
        case .system: Color(.tertiarySystemFill)
        }
    }

    @ViewBuilder
    private func inputBar(_ item: Consultation) -> some View {
        if item.status == .closed || item.isDialogExpired {
            Text("对话已关闭")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.cardBackground)
        } else if item.status == .active {
            VStack(spacing: 8) {
                Text(followUpHint(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("输入追问内容…", text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    Button("发送") { trySend() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.brandTeal)
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .background(AppTheme.cardBackground)
        }
    }

    private func followUpHint(_ item: Consultation) -> String {
        let left = max(0, ConsultationRules.maxFollowUps - item.followUpCount)
        if !item.freeFollowUpUsed {
            return "剩余免费追问：1次 ｜ 第2次起\(ConsultationRules.followUpCost)豆/次 ｜ 还可追问 \(left) 次"
        }
        if beans.followUpCards > 0 {
            return "可用免费追问卡：\(beans.followUpCards) 张 ｜ 否则 \(ConsultationRules.followUpCost)豆/次 ｜ 还可追问 \(left) 次"
        }
        return "第2次起\(ConsultationRules.followUpCost)豆/次 ｜ 还可追问 \(left) 次"
    }

    private func trySend() {
        guard let charge = store.followUpCharge(for: consultationId) else {
            errorMessage = "当前无法追问"
            showError = true
            return
        }
        if case .beans = charge {
            showFollowUpConfirm = true
        } else {
            performSend()
        }
    }

    private func performSend() {
        let text = input
        let result = store.sendFollowUp(id: consultationId, text: text)
        switch result {
        case .success:
            input = ""
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func endDialog() {
        let result = store.endDialogEarly(id: consultationId)
        switch result {
        case .success:
            showRating = true
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func formatHMS(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
