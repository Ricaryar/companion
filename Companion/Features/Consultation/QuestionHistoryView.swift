import SwiftUI

struct QuestionHistoryView: View {
    @Binding var path: NavigationPath
    @State private var store = ConsultationStore.shared

    var body: some View {
        List {
            if store.historyConsultations.isEmpty {
                Text("暂无提问记录")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.historyConsultations) { item in
                    Button {
                        open(item)
                    } label: {
                        historyRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("历史提问")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.processTimeouts() }
    }

    private func historyRow(_ item: Consultation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if store.isUnread(item.id) {
                    Text("未读")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.riskRed)
                        .clipShape(Capsule())
                }
                statusBadge(item)
            }
            Text(item.symptom.rawValue)
                .font(.subheadline.bold())
            Text(doctorLine(item))
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.isUnread(item.id) {
                Text("📩 医生已回复，点击查看")
                    .font(.caption)
                    .foregroundStyle(AppTheme.riskRed)
            } else if item.status == .waiting {
                Text("⏳ 正在等待医生接诊……")
                    .font(.caption)
                    .foregroundStyle(AppTheme.brandTeal)
            } else if item.status == .active, let remain = item.remainingDialogSeconds, remain > 0 {
                Text("💬 对话进行中（剩余 \(formatRemain(remain))）")
                    .font(.caption)
                    .foregroundStyle(AppTheme.brandTeal)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ item: Consultation) -> some View {
        Text(item.status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor(item.status).opacity(0.15))
            .foregroundStyle(statusColor(item.status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: ConsultationStatus) -> Color {
        switch status {
        case .waiting: AppTheme.riskYellow
        case .active: AppTheme.brandTeal
        case .closed: .secondary
        case .cancelled: AppTheme.riskRed
        }
    }

    private func doctorLine(_ item: Consultation) -> String {
        if let doctor = item.doctor {
            return "医生：\(doctor.name)"
        }
        return "医生：暂无"
    }

    private func formatRemain(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        return "\(h) 小时 \(m) 分钟"
    }

    private func open(_ item: Consultation) {
        store.processTimeouts()
        guard let latest = store.consultation(id: item.id) else { return }
        switch latest.status {
        case .waiting:
            path.append(QARoute.waiting(latest.id))
        case .active, .closed:
            path.append(QARoute.chat(latest.id))
        case .cancelled:
            break
        }
    }
}
