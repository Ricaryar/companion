import SwiftUI

struct ConsultationRatingSheet: View {
    let consultationId: String
    var onFinished: () -> Void

    @State private var store = ConsultationStore.shared
    @State private var speed = 5
    @State private var expertise = 5
    @State private var resolved = true
    @State private var showPublish = false
    @State private var errorMessage: String?

    private var item: Consultation? {
        store.consultation(id: consultationId)
    }

    private var ratingTitle: String {
        guard let doctor = item?.doctor else {
            return "关于本次回答的评价"
        }
        let surname = String(doctor.name.prefix(1))
        return "关于\(surname)医生本次回答的评价"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(ratingTitle)
                        .font(.headline)
                }

                Section("回复速度") {
                    starPicker(value: $speed)
                }
                Section("专业程度") {
                    starPicker(value: $expertise)
                }
                Section("是否解决了您的疑问？") {
                    Picker("结果", selection: $resolved) {
                        Text("✅ 解决了").tag(true)
                        Text("❌ 没有解决").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("评价后您将获得 \(ConsultationRules.ratingReward) 健康豆作为奖励")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("评价咨询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交评价") { submitRating() }
                }
            }
            .interactiveDismissDisabled(true)
            .sheet(isPresented: $showPublish) {
                publishSheet
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func starPicker(value: Binding<Int>) -> some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    value.wrappedValue = n
                } label: {
                    Image(systemName: n <= value.wrappedValue ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(value.wrappedValue) 星")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func submitRating() {
        let result = store.submitRating(
            id: consultationId,
            speed: speed,
            expertise: expertise,
            resolved: resolved
        )
        switch result {
        case .success:
            if resolved {
                showPublish = true
            } else {
                store.setPublishConsent(id: consultationId, publish: false)
                onFinished()
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private var publishSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("🙋 是否将此问答公开？")
                    .font(.title3.bold())
                Text("您的问答将匿名展示在「公开问答库」中，帮助更多有相似症状的用户参考。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("公开内容将自动隐藏您的昵称、头像等个人信息，仅保留年龄、性别和症状信息。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 12) {
                    Button("仅我可看") {
                        store.setPublishConsent(id: consultationId, publish: false)
                        onFinished()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("同意公开") {
                        store.setPublishConsent(id: consultationId, publish: true)
                        onFinished()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brandTeal)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .navigationTitle("公开授权")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)
        }
        .presentationDetents([.medium])
    }
}
