import SwiftUI

struct DoctorInboxView: View {
    @State private var store = ConsultationStore.shared
    @State private var doctorStore = DoctorCertificationStore.shared
    @State private var selectedSymptom: SymptomTag = .all
    @State private var segment = 0

    private var waitingList: [Consultation] {
        store.filteredWaiting(symptom: selectedSymptom)
    }

    private var activeList: [Consultation] {
        guard let id = doctorStore.certification?.id else { return [] }
        let list = store.activeConsultations(forDoctorId: id)
        guard selectedSymptom != .all else { return list }
        return list.filter { $0.symptom == selectedSymptom }
    }

    private var activeSegmentTitle: String {
        let base = "咨询中 (\(activeList.count))"
        let unread = store.doctorUnreadTotal
        guard unread > 0 else { return base }
        return "\(base) · 未读\(unread)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $segment) {
                Text("待接诊 (\(store.waitingConsultations.count))").tag(0)
                Text(activeSegmentTitle).tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            filterBar

            if segment == 0 {
                waitingListView
            } else {
                activeListView
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("在线回答")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.processTimeouts() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SymptomTag.allCases) { tag in
                    Button {
                        selectedSymptom = tag
                    } label: {
                        Text(tag.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedSymptom == tag ? AppTheme.brandTeal : AppTheme.cardBackground)
                            .foregroundStyle(selectedSymptom == tag ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var waitingListView: some View {
        Group {
            if waitingList.isEmpty {
                ContentUnavailableView(
                    "暂无待接诊提问",
                    systemImage: "tray",
                    description: Text("新的患者提问会出现在这里")
                )
            } else {
                List(waitingList) { item in
                    NavigationLink {
                        DoctorCaseDetailView(consultationId: item.id)
                    } label: {
                        waitingRow(item)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var activeListView: some View {
        Group {
            if activeList.isEmpty {
                ContentUnavailableView(
                    "暂无进行中咨询",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("接诊后的对话会出现在这里")
                )
            } else {
                List(activeList) { item in
                    NavigationLink {
                        DoctorActiveChatView(consultationId: item.id)
                    } label: {
                        activeRow(item)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func waitingRow(_ item: Consultation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.shortTitle)
                .font(.subheadline.bold())
            Text("\(item.gender)，\(item.age)岁 · \(item.symptom.rawValue) · \(item.duration.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func activeRow(_ item: Consultation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.shortTitle)
                    .font(.subheadline.bold())
                Spacer()
                let unread = store.doctorUnreadCount(for: item.id)
                if unread > 0 {
                    Text("未读消息\(unread)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            if let remain = item.remainingDialogSeconds, remain > 0 {
                Text("剩余 \(formatRemain(remain))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.brandTeal)
            } else {
                Text("对话已结束")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRemain(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        return "\(h)小时\(m)分"
    }
}

struct DoctorCaseDetailView: View {
    let consultationId: String
    @State private var store = ConsultationStore.shared
    @State private var doctorStore = DoctorCertificationStore.shared
    @State private var replyText = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var item: Consultation? {
        store.consultation(id: consultationId)
    }

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("患者提问")
                                .font(.headline)
                            Text("\(item.gender)，\(item.age)岁")
                            Text("症状：\(item.symptom.rawValue) · 持续\(item.duration.rawValue)")
                            Text(item.detail)
                                .font(.subheadline)
                            if !item.medicationNote.isEmpty {
                                Text("就诊/用药：\(item.medicationNote)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .companionCard()

                        if item.status == .waiting {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("首次回复（必填）")
                                    .font(.headline)
                                TextEditor(text: $replyText)
                                    .frame(minHeight: 140)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.2))
                                    )
                                Text("接诊后将通知患者，并开启 6 小时对话窗口。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("接诊并回复") {
                                    accept()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.brandTeal)
                                .frame(maxWidth: .infinity)
                            }
                            .companionCard()
                        } else {
                            Text("该提问已被接诊")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("未找到提问", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle("待接诊详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func accept() {
        guard let doctor = doctorStore.doctorProfile else {
            errorMessage = "请先完成医生认证"
            return
        }
        let result = store.doctorAcceptAndReply(id: consultationId, doctor: doctor, replyText: replyText)
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

struct DoctorActiveChatView: View {
    let consultationId: String
    @State private var store = ConsultationStore.shared
    @State private var doctorStore = DoctorCertificationStore.shared
    @State private var input = ""
    @State private var errorMessage: String?

    private var item: Consultation? {
        store.consultation(id: consultationId)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let item {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(item.messages) { msg in
                            HStack {
                                if msg.sender == .doctor { Spacer(minLength: 40) }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(msg.sender == .user ? "患者" : msg.sender == .doctor ? "我" : "系统")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                    Text(msg.text)
                                        .font(.subheadline)
                                }
                                .padding(10)
                                .background(msg.sender == .doctor ? AppTheme.brandTeal.opacity(0.15) : AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                if msg.sender != .doctor { Spacer(minLength: 40) }
                            }
                        }
                    }
                    .padding()
                }

                if item.status == .active, !item.isDialogExpired {
                    HStack {
                        TextField("回复患者…", text: $input, axis: .vertical)
                            .lineLimit(1...4)
                            .textFieldStyle(.roundedBorder)
                        Button("发送") { send() }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.brandTeal)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                } else {
                    Text("对话已结束")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.cardBackground)
                }
            }
        }
        .navigationTitle("咨询回复")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.markDoctorRead(id: consultationId)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            store.processTimeouts()
        }
        .alert("无法发送", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func send() {
        guard let doctorId = doctorStore.certification?.id else { return }
        let result = store.doctorReply(id: consultationId, doctorId: doctorId, text: input)
        switch result {
        case .success:
            input = ""
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        DoctorInboxView()
    }
}
