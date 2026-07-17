import Foundation
import UIKit

@Observable
final class MedicationShareStore {
    static let shared = MedicationShareStore()

    private(set) var shares: [MedicationShare] = []
    private(set) var cashLedger: [MedicationCashLedgerEntry] = []
    private(set) var cashBalanceCents = 0
    private(set) var unlockedShareIds: Set<String> = []
    private(set) var notices: [MedicationShareNotice] = []
    private(set) var changeToken = 0

    private let fileURL: URL
    private let cashURL: URL
    private let unlockURL: URL
    private let noticesURL: URL
    private let imagesFolder: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("Companion", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("medication-shares.json")
        cashURL = folder.appendingPathComponent("medication-cash.json")
        unlockURL = folder.appendingPathComponent("medication-unlocks.json")
        noticesURL = folder.appendingPathComponent("medication-notices.json")
        imagesFolder = folder.appendingPathComponent("MedicationShareImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
        load()
        loadCash()
        loadUnlocks()
        loadNotices()
        migrateOrdinarySharesToBothIfNeeded()
        seedDemoIfNeeded()
        seedWelcomeNoticeIfNeeded()
    }

    /// 普通价值分享同时投放社区与科普区（兼容旧数据）
    private func migrateOrdinarySharesToBothIfNeeded() {
        var changed = false
        for i in shares.indices {
            if shares[i].status == .approved, !shares[i].isHighValue, shares[i].placement == .scienceTask {
                shares[i].placement = .both
                changed = true
            }
        }
        if changed { save() }
    }

    private func seedWelcomeNoticeIfNeeded() {
        guard notices.isEmpty else { return }
        notices = [
            MedicationShareNotice(
                id: "welcome-notice",
                title: "欢迎使用真实用药通知",
                body: "审核结果、提现进度等消息将在这里提醒您。",
                createdAt: .now,
                isRead: false
            ),
        ]
        saveNotices()
    }

    private func bump() {
        changeToken += 1
        save()
    }

    // MARK: - Queries

    var publishedCommunityShares: [MedicationShare] {
        _ = changeToken
        return shares
            .filter { $0.status == .approved && $0.placement.showsInCommunity }
            .sorted { lhs, rhs in
                // 高价值分享置顶，其余按发布时间倒序
                if lhs.isHighValue != rhs.isHighValue {
                    return lhs.isHighValue
                }
                return (lhs.publishedAt ?? lhs.createdAt) > (rhs.publishedAt ?? rhs.createdAt)
            }
    }

    var scienceTaskShares: [MedicationShare] {
        _ = changeToken
        return shares
            .filter { $0.status == .approved && $0.placement.showsInScienceTask }
            .sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }
    }

    var myShares: [MedicationShare] {
        _ = changeToken
        return shares
            .filter { $0.authorName == "我" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var cashBalanceYuan: Double {
        _ = changeToken
        return Double(cashBalanceCents) / 100.0
    }

    var canWithdraw: Bool {
        cashBalanceCents >= MedicationShareRules.withdrawMinYuan * 100
    }

    var unreadNoticeCount: Int {
        _ = changeToken
        return notices.filter { !$0.isRead }.count
    }

    func share(id: String) -> MedicationShare? {
        _ = changeToken
        return shares.first { $0.id == id }
    }

    func isUnlocked(_ id: String) -> Bool {
        _ = changeToken
        return unlockedShareIds.contains(id)
    }

    func filteredCommunity(
        category: MedicationDiseaseCategory?,
        search: String
    ) -> [MedicationShare] {
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return publishedCommunityShares.filter { item in
            if let category, item.category != category { return false }
            guard !keyword.isEmpty else { return true }
            let hay = [
                item.title, item.summary, item.drugName, item.subtype,
                item.therapyKind.rawValue, item.treatmentLine, item.category.rawValue,
            ].joined(separator: " ").lowercased()
            return hay.contains(keyword)
        }
    }

    // MARK: - Images

    func saveImageData(_ data: Data) -> String? {
        let name = "\(UUID().uuidString).jpg"
        let url = imagesFolder.appendingPathComponent(name)
        let image = UIImage(data: data)
        let jpeg = image?.jpegData(compressionQuality: 0.82) ?? data
        do {
            try jpeg.write(to: url, options: [.atomic])
            return name
        } catch {
            return nil
        }
    }

    func image(named fileName: String) -> UIImage? {
        let url = imagesFolder.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Publish

    struct Draft {
        var title: String
        var summary: String
        var body: String
        var drugName: String
        var category: MedicationDiseaseCategory
        var subtype: String
        var therapyKind: MedicationTherapyKind
        var treatmentLine: String
        var drugImageData: [Data]
        var recordImageData: [Data]
    }

    enum ShareError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case .message(let text) = self { return text }
            return nil
        }
    }

    @discardableResult
    func submit(_ draft: Draft) -> Result<MedicationShare, ShareError> {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let drugName = draft.drugName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return .failure(.message("请填写标题")) }
        guard !summary.isEmpty else { return .failure(.message("请填写摘要")) }
        guard body.count >= 40 else { return .failure(.message("正文请至少写 40 字，便于帮助病友")) }
        guard !drugName.isEmpty else { return .failure(.message("请填写药品名称")) }
        guard !draft.subtype.isEmpty else { return .failure(.message("请完成疾病子类选择")) }
        guard !draft.treatmentLine.isEmpty else { return .failure(.message("请完成治疗线选择")) }
        guard !draft.drugImageData.isEmpty else { return .failure(.message("请上传药品图片")) }
        guard !draft.recordImageData.isEmpty else { return .failure(.message("请上传病历本照片以证明真实性")) }

        let drugFiles = draft.drugImageData.compactMap { saveImageData($0) }
        let recordFiles = draft.recordImageData.compactMap { saveImageData($0) }
        guard drugFiles.count == draft.drugImageData.count,
              recordFiles.count == draft.recordImageData.count else {
            return .failure(.message("图片保存失败，请重试"))
        }

        let eligible = draft.therapyKind.isCashIncentiveEligible
        let highValue = eligible && body.count >= 120
        var item = MedicationShare(
            id: UUID().uuidString,
            title: title,
            summary: summary,
            body: body,
            drugName: drugName,
            category: draft.category,
            subtype: draft.subtype,
            therapyKind: draft.therapyKind,
            treatmentLine: draft.treatmentLine,
            drugImageFileNames: drugFiles,
            recordImageFileNames: recordFiles,
            status: .pending,
            placement: highValue ? .community : .both,
            isIncentiveEligible: eligible,
            isHighValue: highValue,
            viewCount: 0,
            usefulCount: 0,
            authorName: "我",
            createdAt: .now,
            publishedAt: nil,
            auditMessage: nil,
            comments: [],
            baseCashAwarded: false,
            viewBonusAwarded: false,
            usefulBonusAwarded: false,
            cashCentsEarned: 0
        )

        // 本地演示：提交后自动审核
        item = autoAudit(item)
        shares.insert(item, at: 0)
        bump()

        if item.status == .approved, item.isIncentiveEligible, !item.baseCashAwarded {
            _ = awardBaseCashIfNeeded(shareId: item.id)
        }

        return .success(self.share(id: item.id) ?? item)
    }

    private func autoAudit(_ input: MedicationShare) -> MedicationShare {
        var share = input
        share.status = .approved
        share.publishedAt = .now
        if share.isIncentiveEligible, share.isHighValue {
            share.auditMessage = "审核通过，感谢分享真实用药经验。已发放 \(MedicationShareRules.baseCashYuan) 元现金奖励（满 \(MedicationShareRules.withdrawMinYuan) 元可提现）。后续浏览量与「有用」达标还可继续补贴。"
            share.placement = .community
            share.isHighValue = true
            appendNotice(
                title: "分享审核通过",
                body: "「\(share.title)」已发布，并获得 \(MedicationShareRules.baseCashYuan) 元现金奖励。"
            )
        } else if share.isIncentiveEligible {
            share.auditMessage = "审核通过，感谢分享。已发放 \(MedicationShareRules.baseCashYuan) 元现金奖励。您的普通价值分享已同时投放至真实用药社区与科普任务区。"
            share.placement = .both
            share.isHighValue = false
            appendNotice(
                title: "分享审核通过",
                body: "「\(share.title)」已发布并获得 \(MedicationShareRules.baseCashYuan) 元，已同步投放社区与科普区。"
            )
        } else {
            share.auditMessage = "感谢分享，但常见药暂不纳入现金激励范围。您的分享已同时投放至真实用药社区与科普区（积分任务）。"
            share.placement = .both
            share.isHighValue = false
            appendNotice(
                title: "分享已投放",
                body: "「\(share.title)」审核完成：常见药暂不纳入现金激励，已投放至社区与科普区。"
            )
            HealthBeansStore.shared.creditBeans(
                MedicationShareRules.scienceTaskBeans,
                title: "真实用药分享投放科普区"
            )
        }
        return share
    }

    // MARK: - Engagement

    func markViewed(id: String) {
        guard let index = shares.firstIndex(where: { $0.id == id }) else { return }
        shares[index].viewCount += 1
        bump()
        maybeAwardViewBonus(shareId: id)
        // 高热后可持续补贴：本地演示为浏览破阈值后提升为高价值，仅保留社区投放
        if shares[index].isIncentiveEligible,
           shares[index].viewCount >= MedicationShareRules.highValueViewThreshold {
            shares[index].isHighValue = true
            shares[index].placement = .community
            bump()
        }
    }

    @discardableResult
    func toggleUseful(id: String) -> Bool {
        guard let index = shares.firstIndex(where: { $0.id == id }) else { return false }
        // 简化：每次点击 +1（本地演示）
        shares[index].usefulCount += 1
        bump()
        maybeAwardUsefulBonus(shareId: id)
        return true
    }

    func addComment(id: String, text: String) -> Result<Void, ShareError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.message("请输入评论内容")) }
        guard let index = shares.firstIndex(where: { $0.id == id }) else {
            return .failure(.message("未找到该分享"))
        }
        let comment = MedicationShareComment(
            id: UUID().uuidString,
            authorName: "病友",
            text: trimmed,
            createdAt: .now
        )
        shares[index].comments.append(comment)
        bump()
        return .success(())
    }

    func unlockAfterAd(id: String) {
        unlockedShareIds.insert(id)
        saveUnlocks()
        changeToken += 1
        // 广告收入部分注入奖金池：本地演示给作者 +0.5 元
        creditAuthorCash(shareId: id, cents: 50, title: "广告解锁分成")
    }

    // MARK: - Cash

    @discardableResult
    private func awardBaseCashIfNeeded(shareId: String) -> Bool {
        guard let index = shares.firstIndex(where: { $0.id == shareId }) else { return false }
        guard shares[index].isIncentiveEligible, !shares[index].baseCashAwarded else { return false }
        let cents = MedicationShareRules.baseCashYuan * 100
        shares[index].baseCashAwarded = true
        shares[index].cashCentsEarned += cents
        creditWallet(cents: cents, title: "分享审核通过奖励")
        bump()
        return true
    }

    private func maybeAwardViewBonus(shareId: String) {
        guard let index = shares.firstIndex(where: { $0.id == shareId }) else { return }
        guard shares[index].isIncentiveEligible,
              !shares[index].viewBonusAwarded,
              shares[index].viewCount >= MedicationShareRules.viewBonusThreshold else { return }
        let cents = MedicationShareRules.viewBonusYuan * 100
        shares[index].viewBonusAwarded = true
        shares[index].cashCentsEarned += cents
        creditWallet(cents: cents, title: "浏览量达标额外奖励")
        bump()
    }

    private func maybeAwardUsefulBonus(shareId: String) {
        guard let index = shares.firstIndex(where: { $0.id == shareId }) else { return }
        guard shares[index].isIncentiveEligible,
              !shares[index].usefulBonusAwarded,
              shares[index].usefulCount >= MedicationShareRules.usefulBonusThreshold else { return }
        let cents = MedicationShareRules.usefulBonusYuan * 100
        shares[index].usefulBonusAwarded = true
        shares[index].cashCentsEarned += cents
        creditWallet(cents: cents, title: "「有用」点赞达标奖励")
        bump()
    }

    private func creditAuthorCash(shareId: String, cents: Int, title: String) {
        guard cents > 0, let index = shares.firstIndex(where: { $0.id == shareId }) else { return }
        // 仅当作者是「我」时入账本地钱包
        guard shares[index].authorName == "我" else {
            shares[index].cashCentsEarned += cents
            bump()
            return
        }
        shares[index].cashCentsEarned += cents
        creditWallet(cents: cents, title: title)
        bump()
    }

    private func creditWallet(cents: Int, title: String) {
        cashBalanceCents += cents
        let entry = MedicationCashLedgerEntry(
            id: UUID().uuidString,
            date: .now,
            title: title,
            amountCents: cents,
            balanceAfterCents: cashBalanceCents
        )
        cashLedger.insert(entry, at: 0)
        saveCash()
        changeToken += 1
    }

    @discardableResult
    func withdrawAll() -> Result<Int, ShareError> {
        guard canWithdraw else {
            return .failure(.message("满 \(MedicationShareRules.withdrawMinYuan) 元才可提现，当前余额 \(String(format: "%.2f", cashBalanceYuan)) 元"))
        }
        let amount = cashBalanceCents
        cashBalanceCents = 0
        let entry = MedicationCashLedgerEntry(
            id: UUID().uuidString,
            date: .now,
            title: "提现至微信（演示）",
            amountCents: -amount,
            balanceAfterCents: cashBalanceCents
        )
        cashLedger.insert(entry, at: 0)
        saveCash()
        changeToken += 1
        appendNotice(
            title: "提现申请已提交",
            body: String(format: "已申请提现 ¥%.2f（演示环境模拟处理）。", Double(amount) / 100)
        )
        return .success(amount)
    }

    // MARK: - Notices

    func appendNotice(title: String, body: String) {
        let notice = MedicationShareNotice(
            id: UUID().uuidString,
            title: title,
            body: body,
            createdAt: .now,
            isRead: false
        )
        notices.insert(notice, at: 0)
        saveNotices()
        changeToken += 1
    }

    func markNoticeRead(id: String) {
        guard let index = notices.firstIndex(where: { $0.id == id }) else { return }
        guard !notices[index].isRead else { return }
        notices[index].isRead = true
        saveNotices()
        changeToken += 1
    }

    func markAllNoticesRead() {
        guard notices.contains(where: { !$0.isRead }) else { return }
        for i in notices.indices {
            notices[i].isRead = true
        }
        saveNotices()
        changeToken += 1
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(shares) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([MedicationShare].self, from: data) else {
            shares = []
            return
        }
        shares = decoded
    }

    private struct CashState: Codable {
        var balanceCents: Int
        var ledger: [MedicationCashLedgerEntry]
    }

    private func saveCash() {
        let state = CashState(balanceCents: cashBalanceCents, ledger: cashLedger)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: cashURL, options: [.atomic])
    }

    private func loadCash() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: cashURL),
              let decoded = try? decoder.decode(CashState.self, from: data) else {
            cashBalanceCents = 0
            cashLedger = []
            return
        }
        cashBalanceCents = decoded.balanceCents
        cashLedger = decoded.ledger
    }

    private func saveUnlocks() {
        let ids = Array(unlockedShareIds)
        guard let data = try? JSONEncoder().encode(ids) else { return }
        try? data.write(to: unlockURL, options: [.atomic])
    }

    private func loadUnlocks() {
        guard let data = try? Data(contentsOf: unlockURL),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            unlockedShareIds = []
            return
        }
        unlockedShareIds = Set(ids)
    }

    private func saveNotices() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(notices) else { return }
        try? data.write(to: noticesURL, options: [.atomic])
    }

    private func loadNotices() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: noticesURL),
              let decoded = try? decoder.decode([MedicationShareNotice].self, from: data) else {
            notices = []
            return
        }
        notices = decoded
    }

    private func seedDemoIfNeeded() {
        guard shares.isEmpty else { return }
        let demos: [MedicationShare] = [
            MedicationShare(
                id: "demo-med-1",
                title: "XX靶向药用药30天记录：副作用变化+血项追踪",
                summary: "非小细胞肺癌一线靶向治疗首月：皮疹、转氨酶与咳嗽变化的真实记录。",
                body: """
                确诊非小细胞肺癌后，医生建议一线靶向治疗。服药第1周出现轻度皮疹与食欲下降，第2周咳嗽减轻，第3–4周复查血项时转氨酶轻度升高，医生调整了护肝与皮肤护理方案。

                本记录仅供病友参考交流，不能替代面诊与个体化医嘱。如有疑问，请到「提问」咨询医生是否适合您的情况。
                """,
                drugName: "演示靶向药 A",
                category: .oncology,
                subtype: "非小细胞肺癌",
                therapyKind: .targeted,
                treatmentLine: "一线治疗",
                drugImageFileNames: [],
                recordImageFileNames: [],
                status: .approved,
                placement: .community,
                isIncentiveEligible: true,
                isHighValue: true,
                viewCount: 128,
                usefulCount: 36,
                authorName: "病友小周",
                createdAt: Date().addingTimeInterval(-86400 * 3),
                publishedAt: Date().addingTimeInterval(-86400 * 3),
                auditMessage: nil,
                comments: [
                    MedicationShareComment(
                        id: "c1",
                        authorName: "同行病友",
                        text: "血项追踪很有参考价值，已收藏。",
                        createdAt: Date().addingTimeInterval(-86400)
                    ),
                ],
                baseCashAwarded: true,
                viewBonusAwarded: false,
                usefulBonusAwarded: false,
                cashCentsEarned: 500
            ),
            MedicationShare(
                id: "demo-med-2",
                title: "布洛芬退热使用记录（常见药）",
                summary: "发热时按说明书使用的个人体验，已投放社区与科普区。",
                body: """
                偶发发热时按说明书服用布洛芬，注意补水与体温监测。本分享属于常见非处方药，不纳入现金激励，同时投放真实用药社区与科普任务区供参考。
                """,
                drugName: "布洛芬",
                category: .respiratory,
                subtype: "其他",
                therapyKind: .commonOTC,
                treatmentLine: "对症治疗",
                drugImageFileNames: [],
                recordImageFileNames: [],
                status: .approved,
                placement: .both,
                isIncentiveEligible: false,
                isHighValue: false,
                viewCount: 42,
                usefulCount: 5,
                authorName: "匿名用户",
                createdAt: Date().addingTimeInterval(-86400 * 5),
                publishedAt: Date().addingTimeInterval(-86400 * 5),
                auditMessage: "常见药已投放科普区",
                comments: [],
                baseCashAwarded: false,
                viewBonusAwarded: false,
                usefulBonusAwarded: false,
                cashCentsEarned: 0
            ),
            MedicationShare(
                id: "demo-med-3",
                title: "罕见病用药半年随访问答",
                summary: "长期处方管理、复查节奏与不良反应沟通要点。",
                body: """
                罕见病用药往往需要更长随访。我把半年内复查节点、剂量调整沟通方式与生活管理经验整理如下，希望帮助同样在等待信息的病友。

                请务必结合自身检查结果咨询专科医生，不要自行更改剂量。
                """,
                drugName: "演示罕见病用药 B",
                category: .rareOther,
                subtype: "罕见病",
                therapyKind: .rareDisease,
                treatmentLine: "维持治疗",
                drugImageFileNames: [],
                recordImageFileNames: [],
                status: .approved,
                placement: .community,
                isIncentiveEligible: true,
                isHighValue: true,
                viewCount: 86,
                usefulCount: 21,
                authorName: "病友阿陈",
                createdAt: Date().addingTimeInterval(-86400 * 8),
                publishedAt: Date().addingTimeInterval(-86400 * 8),
                auditMessage: nil,
                comments: [],
                baseCashAwarded: true,
                viewBonusAwarded: false,
                usefulBonusAwarded: false,
                cashCentsEarned: 500
            ),
        ]
        shares = demos
        save()
    }
}
