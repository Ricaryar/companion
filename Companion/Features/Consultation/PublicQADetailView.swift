import SwiftUI

struct PublicQADetailView: View {
    let consultationId: String
    @Binding var path: NavigationPath
    @State private var store = ConsultationStore.shared

    private var item: Consultation? {
        store.consultation(id: consultationId)
    }

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(item)
                        section(title: "病情描述") {
                            Text(item.detail)
                                .font(.subheadline)
                            if !item.medicationNote.isEmpty {
                                Text("已就诊/用药：\(item.medicationNote)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let doctor = item.doctor {
                            section(title: "医生信息") {
                            Label("\(doctor.name) · \(doctor.title) · \(doctor.department)", systemImage: doctor.avatarSymbol)
                                .font(.subheadline)
                            Text(doctor.hospital)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        section(title: "对话记录") {
                            ForEach(item.messages.filter { $0.sender != .system }) { msg in
                                messageBubble(msg)
                            }
                        }
                        if let rating = item.rating {
                            section(title: "评价") {
                                Text(String(format: "综合 %.1f 星 · %@", rating.averageStars, rating.resolved ? "已解决" : "未解决"))
                                    .font(.subheadline)
                            }
                        }
                        disclaimer
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("未找到问答", systemImage: "questionmark.circle")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("问答详情")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                if store.hasPendingRating {
                    // stay
                } else {
                    path.append(QARoute.askForm)
                }
            } label: {
                Text("我要提问")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.brandTeal)
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func header(_ item: Consultation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.shortTitle)
                .font(.title3.bold())
            Text("\(item.gender)，\(item.age)岁 · \(item.symptom.rawValue) · 持续\(item.duration.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .companionCard()
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .companionCard()
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(msg.sender == .user ? "用户" : "医生")
                .font(.caption.bold())
                .foregroundStyle(msg.sender == .doctor ? AppTheme.brandTeal : .secondary)
            Text(msg.text)
                .font(.subheadline)
            Text(msg.createdAt, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(msg.sender == .doctor ? AppTheme.brandTeal.opacity(0.08) : Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var disclaimer: some View {
        Text("📌 此问答仅供参考，不能代替线下诊断。如有不适，请点击「我要提问」发起个人咨询。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}
