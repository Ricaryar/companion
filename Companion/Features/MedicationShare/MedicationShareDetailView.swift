import SwiftUI

struct MedicationShareDetailView: View {
    let shareId: String

    @State private var store = MedicationShareStore.shared
    @State private var commentText = ""
    @State private var showAdGate = false
    @State private var showAdPlaying = false
    @State private var adSecondsLeft = MedicationShareRules.adUnlockSeconds
    @State private var errorMessage: String?
    @State private var toast: String?

    private var share: MedicationShare? {
        store.share(id: shareId)
    }

    private var needsUnlock: Bool {
        guard let share else { return false }
        return share.isHighValue && !store.isUnlocked(shareId) && share.authorName != "我"
    }

    var body: some View {
        Group {
            if let share {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(share)
                        summaryCard(share)
                        if needsUnlock {
                            lockedPreview(share)
                        } else {
                            fullContent(share)
                        }
                        askDoctorGuide
                        commentsSection(share)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("未找到分享", systemImage: "pills")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("用药分享")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.markViewed(id: shareId)
        }
        .sheet(isPresented: $showAdGate) {
            adGateSheet
        }
        .sheet(isPresented: $showAdPlaying) {
            adPlayingSheet
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.brandGraphite.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
        }
    }

    private func header(_ share: MedicationShare) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(share.title)
                .font(.title3.bold())
            Text(share.categoryPathText)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text(share.authorName)
                Label("\(share.viewCount) 浏览", systemImage: "eye")
                Label("\(share.usefulCount) 有用", systemImage: "hand.thumbsup")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func summaryCard(_ share: MedicationShare) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("摘要")
                .font(.headline)
            Text(share.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LabeledContent("药品", value: share.drugName)
                .font(.caption)
        }
        .companionCard()
    }

    private func lockedPreview(_ share: MedicationShare) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(share.body.prefix(80)) + "…")
                .font(.body)
                .foregroundStyle(.secondary)
                .redacted(reason: .placeholder)

            Button {
                showAdGate = true
            } label: {
                Text("查看全文")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.brandTeal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .companionCard()
    }

    private func fullContent(_ share: MedicationShare) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全文")
                .font(.headline)
            Text(share.body)
                .font(.body)

            imageStrip(title: "药品图片", names: share.drugImageFileNames)
            imageStrip(title: "病历本（真实性证明）", names: share.recordImageFileNames)

            Button {
                _ = store.toggleUseful(id: shareId)
                showToast("已标记有用，感谢反馈")
            } label: {
                Label("有用 \(share.usefulCount)", systemImage: "hand.thumbsup.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.brandTeal)
        }
        .companionCard()
    }

    private func imageStrip(title: String, names: [String]) -> some View {
        Group {
            if !names.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.subheadline.bold())
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(names, id: \.self) { name in
                                if let image = store.image(named: name) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var askDoctorGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("有疑问？")
                .font(.headline)
            Text("药品是否适合自己，请结合个人病情咨询医生。可前往「提问」花费健康豆询问。")
                .font(.caption)
                .foregroundStyle(.secondary)
            NavigationLink {
                PublicQALibraryView()
            } label: {
                Label("去提问咨询医生", systemImage: "stethoscope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .companionCard()
    }

    private func commentsSection(_ share: MedicationShare) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("评论区")
                .font(.headline)
            if share.comments.isEmpty {
                Text("还没有评论，来发表你的看法吧")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(share.comments) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(comment.authorName)
                                .font(.caption.bold())
                            Spacer()
                            Text(comment.createdAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(comment.text)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField("发表看法…", text: $commentText, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                Button("发送") {
                    switch store.addComment(id: shareId, text: commentText) {
                    case .success:
                        commentText = ""
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brandTeal)
            }
        }
        .companionCard()
    }

    private var adGateSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("📋 该分享为高价值经验")
                    .font(.title3.bold())
                Text("观看一段 15-30秒 广告即可完整查看\n广告收入将部分注入分享者奖金池")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("您的每次观看都在支持分享者 ❤️")
                    .font(.subheadline)
                Spacer()
                Button {
                    showAdGate = false
                    adSecondsLeft = MedicationShareRules.adUnlockSeconds
                    showAdPlaying = true
                } label: {
                    Text("看广告解锁全文")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.brandTeal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .navigationTitle("解锁全文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showAdGate = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var adPlayingSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.brandIndigo)
                Text("广告播放中（演示）")
                    .font(.headline)
                Text("剩余 \(adSecondsLeft) 秒")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(AppTheme.brandTeal)
                Text("正式版将接入真实激励视频广告")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if adSecondsLeft == 0 {
                    Button("完成并解锁") {
                        store.unlockAfterAd(id: shareId)
                        showAdPlaying = false
                        showToast("已解锁全文，感谢支持分享者")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brandTeal)
                } else {
                    ProgressView(value: Double(MedicationShareRules.adUnlockSeconds - adSecondsLeft),
                                 total: Double(MedicationShareRules.adUnlockSeconds))
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("观看广告")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(adSecondsLeft > 0)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if adSecondsLeft > 0 {
                    adSecondsLeft -= 1
                }
            }
        }
    }

    private func showToast(_ message: String) {
        toast = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if toast == message { toast = nil }
        }
    }
}
