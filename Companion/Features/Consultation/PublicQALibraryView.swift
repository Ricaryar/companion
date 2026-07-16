import SwiftUI

struct PublicQALibraryView: View {
    @State private var store = ConsultationStore.shared
    @State private var deepLink = ConsultationDeepLink.shared
    @State private var selectedSymptom: SymptomTag = .all
    @State private var path = NavigationPath()
    @State private var showAskBlockedAlert = false

    private var list: [Consultation] {
        store.filteredPublic(symptom: selectedSymptom)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if store.unreadCount > 0 {
                        unreadBanner
                    }
                    filterBar
                    if list.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(list) { item in
                                    Button {
                                        store.incrementViewCount(id: item.id)
                                        path.append(QARoute.detail(item.id))
                                    } label: {
                                        PublicQACard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .padding(.bottom, 88)
                        }
                    }
                }

                askFAB
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("大家问")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(QARoute.history)
                    } label: {
                        HStack(spacing: 4) {
                            Text("历史提问")
                            if store.unreadCount > 0 {
                                Text("\(store.unreadCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.riskRed)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: QARoute.self) { route in
                switch route {
                case .detail(let id):
                    PublicQADetailView(consultationId: id, path: $path)
                case .history:
                    QuestionHistoryView(path: $path)
                case .askForm:
                    AskQuestionFormView(path: $path)
                case .waiting(let id):
                    WaitingDoctorView(consultationId: id, path: $path)
                case .chat(let id):
                    ConsultationChatView(consultationId: id, path: $path)
                }
            }
            .onAppear {
                store.processTimeouts()
                openPendingChatIfNeeded()
            }
            .onChange(of: deepLink.pendingChatId) { _, _ in
                openPendingChatIfNeeded()
            }
            .alert("暂不可提问", isPresented: $showAskBlockedAlert) {
                Button("去评价", role: .none) {}
                Button("知道了", role: .cancel) {}
            } message: {
                Text("请先完成上一次咨询的强制评价后，再发起新的提问。浏览公开问答不受影响。")
            }
        }
    }

    private var unreadBanner: some View {
        Button {
            if let id = store.unreadConsultationIds.sorted().first {
                path.append(QARoute.chat(id))
            } else {
                path.append(QARoute.history)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.orange)
                Text("您有 \(store.unreadCount) 条医生未读回复，点击查看")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.12))
        }
        .buttonStyle(.plain)
    }

    private func openPendingChatIfNeeded() {
        guard let id = deepLink.consumePendingChatId() else { return }
        path.append(QARoute.chat(id))
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
            .padding(.vertical, 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("暂无公开问答")
                .font(.headline)
            Text("成为第一个提问并选择公开的人吧")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var askFAB: some View {
        Button {
            if store.hasPendingRating {
                showAskBlockedAlert = true
            } else {
                path.append(QARoute.askForm)
            }
        } label: {
            Label("我要提问", systemImage: "plus.bubble.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.brandTeal)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

enum QARoute: Hashable {
    case detail(String)
    case history
    case askForm
    case waiting(String)
    case chat(String)
}

struct PublicQACard: View {
    let item: Consultation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📋 \(item.shortTitle)")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text("👤 \(item.gender)，\(item.age)岁 · 症状持续\(item.duration.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                stars(item.rating?.averageStars ?? 0)
                Text(String(format: "(%.1f)", item.rating?.averageStars ?? 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text("\(item.viewCount)人浏览")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let doctor = item.doctor {
                Text("👨‍⚕️ \(doctor.name) \(doctor.title) · \(doctor.department)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.brandIndigo)
                Text(doctor.hospital)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(relativeTime(item.publicPublishedAt ?? item.closedAt ?? item.createdAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .companionCard()
    }

    private func stars(_ value: Double) -> some View {
        let filled = Int(value.rounded())
        return HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= filled ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "1天前" }
        return "\(days)天前"
    }
}

#Preview {
    PublicQALibraryView()
}
