import Foundation
import UserNotifications

@Observable
final class ConsultationStore {
    static let shared = ConsultationStore()

    private(set) var consultations: [Consultation] = []
    private(set) var changeToken = 0
    private(set) var unreadConsultationIds: Set<String> = []
    /// 医生端：各咨询的未读患者追问数
    private(set) var doctorUnreadCounts: [String: Int] = [:]

    private let fileURL: URL
    private let unreadURL: URL
    private let doctorUnreadURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("Companion", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("consultations.json")
        unreadURL = folder.appendingPathComponent("consultation-unread.json")
        doctorUnreadURL = folder.appendingPathComponent("doctor-unread.json")
        load()
        loadUnread()
        loadDoctorUnread()
        purgeDemoData()
        processTimeouts()
    }

    private func bump() {
        changeToken += 1
        save()
    }

    private func purgeDemoData() {
        let before = consultations.count
        consultations.removeAll { $0.id.hasPrefix("demo-") }
        if consultations.count != before {
            save()
            changeToken += 1
        }
    }

    var unreadCount: Int {
        _ = changeToken
        return unreadConsultationIds.count
    }

    var doctorUnreadTotal: Int {
        _ = changeToken
        return doctorUnreadCounts.values.reduce(0, +)
    }

    func doctorUnreadCount(for id: String) -> Int {
        _ = changeToken
        return doctorUnreadCounts[id] ?? 0
    }

    func isUnread(_ id: String) -> Bool {
        _ = changeToken
        return unreadConsultationIds.contains(id)
    }

    func markRead(id: String) {
        guard unreadConsultationIds.contains(id) else { return }
        unreadConsultationIds.remove(id)
        saveUnread()
        changeToken += 1
        updatePatientBadge()
    }

    func markDoctorRead(id: String) {
        guard doctorUnreadCounts[id] != nil else { return }
        doctorUnreadCounts.removeValue(forKey: id)
        saveDoctorUnread()
        changeToken += 1
    }

    private func markUnreadAndNotifyPatient(id: String) {
        unreadConsultationIds.insert(id)
        saveUnread()
        changeToken += 1
        updatePatientBadge()
        Task { @MainActor in
            await NotificationScheduler.deliverNow(
                id: "consultation-reply-\(id)-\(UUID().uuidString)",
                title: CopyStrings.appNameZH,
                body: "您的提问已有医生进行回复，点击查看",
                userInfo: [NotificationScheduler.consultationIdKey: id]
            )
        }
    }

    private func markDoctorUnreadAndNotify(id: String) {
        doctorUnreadCounts[id, default: 0] += 1
        saveDoctorUnread()
        changeToken += 1
        Task { @MainActor in
            await NotificationScheduler.deliverNow(
                id: "doctor-followup-\(id)-\(UUID().uuidString)",
                title: CopyStrings.appNameZH,
                body: "患者追问了新问题，点击查看",
                userInfo: [
                    NotificationScheduler.consultationIdKey: id,
                    NotificationScheduler.notificationTypeKey: NotificationScheduler.doctorFollowUpType,
                ]
            )
        }
    }

    private func updatePatientBadge() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.badgeSetting == .enabled || settings.authorizationStatus == .authorized else { return }
            try? await center.setBadgeCount(unreadConsultationIds.count)
        }
    }

    private func loadUnread() {
        guard let data = try? Data(contentsOf: unreadURL),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            unreadConsultationIds = []
            return
        }
        unreadConsultationIds = Set(ids)
    }

    private func saveUnread() {
        let ids = Array(unreadConsultationIds)
        guard let data = try? JSONEncoder().encode(ids) else { return }
        try? data.write(to: unreadURL, options: [.atomic])
    }

    private func loadDoctorUnread() {
        guard let data = try? Data(contentsOf: doctorUnreadURL),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            doctorUnreadCounts = [:]
            return
        }
        doctorUnreadCounts = decoded
    }

    private func saveDoctorUnread() {
        guard let data = try? JSONEncoder().encode(doctorUnreadCounts) else { return }
        try? data.write(to: doctorUnreadURL, options: [.atomic])
    }

    // MARK: - Queries

    var publicConsultations: [Consultation] {
        _ = changeToken
        return consultations
            .filter { $0.isPublic == true && $0.status == .closed && $0.rating != nil }
            .sorted { ($0.publicPublishedAt ?? $0.closedAt ?? $0.createdAt) > ($1.publicPublishedAt ?? $1.closedAt ?? $1.createdAt) }
    }

    var waitingConsultations: [Consultation] {
        _ = changeToken
        processTimeouts()
        return consultations
            .filter { $0.status == .waiting }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var historyConsultations: [Consultation] {
        _ = changeToken
        return consultations
            .filter { $0.status != .cancelled }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var pendingRatingConsultation: Consultation? {
        _ = changeToken
        processTimeouts()
        return consultations
            .filter { $0.status == .closed && $0.rating == nil }
            .sorted { ($0.closedAt ?? $0.createdAt) < ($1.closedAt ?? $1.createdAt) }
            .first
    }

    var hasPendingRating: Bool {
        pendingRatingConsultation != nil
    }

    func consultation(id: String) -> Consultation? {
        _ = changeToken
        return consultations.first { $0.id == id }
    }

    func filteredPublic(symptom: SymptomTag) -> [Consultation] {
        let list = publicConsultations
        guard symptom != .all else { return list }
        return list.filter { $0.symptom == symptom }
    }

    func filteredWaiting(symptom: SymptomTag) -> [Consultation] {
        let list = waitingConsultations
        guard symptom != .all else { return list }
        return list.filter { $0.symptom == symptom }
    }

    func activeConsultations(forDoctorId doctorId: String) -> [Consultation] {
        _ = changeToken
        processTimeouts()
        return consultations
            .filter { $0.status == .active && $0.assignedDoctorId == doctorId }
            .sorted { ($0.doctorFirstReplyAt ?? $0.createdAt) > ($1.doctorFirstReplyAt ?? $1.createdAt) }
    }

    // MARK: - Create / Cancel

    @discardableResult
    func submitConsultation(
        gender: String,
        age: Int,
        symptom: SymptomTag,
        duration: SymptomDuration,
        detail: String,
        medicationNote: String,
        imageCount: Int
    ) -> Result<Consultation, ConsultationError> {
        processTimeouts()
        if hasPendingRating {
            return .failure(.message("请先完成上一次咨询评价后，再发起新的提问。"))
        }
        let cost = HealthBeansStore.shared.consultationAskCost
        guard HealthBeansStore.shared.spendBeans(cost, title: "发起图文咨询") else {
            return .failure(.message("健康豆不足（需要 \(cost) 豆），请先完成任务或充值。"))
        }

        let now = Date()
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            sender: .user,
            text: detail,
            createdAt: now
        )
        let item = Consultation(
            id: UUID().uuidString,
            createdAt: now,
            status: .waiting,
            gender: gender,
            age: age,
            symptom: symptom,
            duration: duration,
            detail: detail,
            medicationNote: medicationNote,
            imageCount: imageCount,
            chargedBeans: cost,
            refunded: false,
            doctor: nil,
            assignedDoctorId: nil,
            doctorFirstReplyAt: nil,
            closedAt: nil,
            waitingDeadline: now.addingTimeInterval(ConsultationRules.waitingTimeout),
            messages: [userMessage],
            followUpCount: 0,
            freeFollowUpUsed: false,
            rating: nil,
            isPublic: nil,
            viewCount: 0,
            publicPublishedAt: nil
        )
        consultations.insert(item, at: 0)
        bump()
        return .success(item)
    }

    @discardableResult
    func cancelWaiting(id: String) -> Result<Void, ConsultationError> {
        guard let index = consultations.firstIndex(ofId: id) else {
            return .failure(.message("未找到该咨询"))
        }
        guard consultations[index].status == .waiting else {
            return .failure(.message("当前状态无法取消"))
        }

        let amount = consultations[index].chargedBeans
        if !consultations[index].refunded {
            HealthBeansStore.shared.refundBeans(amount, title: "取消咨询退还")
            consultations[index].refunded = true
        }
        consultations[index].status = .cancelled
        consultations[index].messages.append(
            ChatMessage(
                id: UUID().uuidString,
                sender: .system,
                text: "您已取消咨询，\(amount) 健康豆已全额退还。",
                createdAt: .now
            )
        )
        bump()
        return .success(())
    }

    // MARK: - Doctor

    @discardableResult
    func doctorAcceptAndReply(id: String, doctor: DoctorProfile, replyText: String) -> Result<Void, ConsultationError> {
        processTimeouts()
        guard let index = consultations.firstIndex(ofId: id) else {
            return .failure(.message("未找到该咨询"))
        }
        guard consultations[index].status == .waiting else {
            return .failure(.message("该提问已被其他医生接诊或已取消"))
        }
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else {
            return .failure(.message("回复内容至少 10 个字"))
        }

        let now = Date()
        consultations[index].doctor = doctor
        consultations[index].assignedDoctorId = doctor.id
        consultations[index].doctorFirstReplyAt = now
        consultations[index].status = .active
        consultations[index].messages.append(
            ChatMessage(id: UUID().uuidString, sender: .doctor, text: trimmed, createdAt: now)
        )
        bump()
        markUnreadAndNotifyPatient(id: id)
        return .success(())
    }

    @discardableResult
    func doctorReply(id: String, doctorId: String, text: String) -> Result<Void, ConsultationError> {
        processTimeouts()
        guard let index = consultations.firstIndex(ofId: id) else {
            return .failure(.message("未找到该咨询"))
        }
        guard consultations[index].status == .active,
              consultations[index].assignedDoctorId == doctorId,
              !consultations[index].isDialogExpired else {
            return .failure(.message("当前无法回复"))
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.message("请输入回复内容")) }

        consultations[index].messages.append(
            ChatMessage(id: UUID().uuidString, sender: .doctor, text: trimmed, createdAt: .now)
        )
        bump()
        markUnreadAndNotifyPatient(id: id)
        return .success(())
    }

    // MARK: - Chat (patient)

    enum FollowUpCharge {
        case free
        case voucher
        case beans(Int)
    }

    func followUpCharge(for id: String) -> FollowUpCharge? {
        guard let c = consultation(id: id), c.canFollowUp else { return nil }
        if !c.freeFollowUpUsed { return .free }
        if HealthBeansStore.shared.followUpCards > 0 { return .voucher }
        return .beans(ConsultationRules.followUpCost)
    }

    @discardableResult
    func sendFollowUp(id: String, text: String) -> Result<Void, ConsultationError> {
        processTimeouts()
        guard let index = consultations.firstIndex(ofId: id) else {
            return .failure(.message("未找到该咨询"))
        }
        var c = consultations[index]
        guard c.canFollowUp else {
            return .failure(.message("当前无法追问（对话已关闭或次数用尽）"))
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.message("请输入追问内容")) }

        if c.freeFollowUpUsed {
            if HealthBeansStore.shared.followUpCards > 0 {
                _ = HealthBeansStore.shared.consumeFollowUpCard()
            } else {
                guard HealthBeansStore.shared.spendBeans(ConsultationRules.followUpCost, title: "咨询追问") else {
                    return .failure(.message("健康豆不足，追问需要 \(ConsultationRules.followUpCost) 豆"))
                }
            }
        } else {
            c.freeFollowUpUsed = true
        }

        c.followUpCount += 1
        c.messages.append(
            ChatMessage(id: UUID().uuidString, sender: .user, text: trimmed, createdAt: .now)
        )
        consultations[index] = c
        bump()
        markDoctorUnreadAndNotify(id: id)
        return .success(())
    }

    // MARK: - Rating / Publish

    @discardableResult
    func submitRating(id: String, speed: Int, expertise: Int, resolved: Bool) -> Result<Void, ConsultationError> {
        guard let index = consultations.firstIndex(ofId: id) else {
            return .failure(.message("未找到该咨询"))
        }
        guard consultations[index].status == .closed else {
            return .failure(.message("仅已关闭的咨询可评价"))
        }
        guard consultations[index].rating == nil else {
            return .failure(.message("已评价过"))
        }
        consultations[index].rating = ConsultationRating(
            speedStars: speed,
            expertiseStars: expertise,
            resolved: resolved,
            createdAt: .now
        )
        HealthBeansStore.shared.refundBeans(ConsultationRules.ratingReward, title: "评价咨询奖励")
        bump()
        return .success(())
    }

    func setPublishConsent(id: String, publish: Bool) {
        guard let index = consultations.firstIndex(ofId: id) else { return }
        consultations[index].isPublic = publish
        if publish {
            consultations[index].publicPublishedAt = .now
        }
        bump()
    }

    func incrementViewCount(id: String) {
        guard let index = consultations.firstIndex(ofId: id) else { return }
        consultations[index].viewCount += 1
        bump()
    }

    // MARK: - Timeouts

    func processTimeouts() {
        let now = Date()
        var changed = false
        for i in consultations.indices {
            if consultations[i].status == .waiting, now >= consultations[i].waitingDeadline {
                let amount = consultations[i].chargedBeans
                if !consultations[i].refunded {
                    HealthBeansStore.shared.refundBeans(amount, title: "超时未接诊退还")
                    consultations[i].refunded = true
                }
                consultations[i].status = .cancelled
                consultations[i].messages.append(
                    ChatMessage(
                        id: UUID().uuidString,
                        sender: .system,
                        text: "24 小时内暂无医生接诊，咨询已自动取消，\(amount) 健康豆已全额退还。",
                        createdAt: now
                    )
                )
                changed = true
            } else if consultations[i].status == .active, consultations[i].isDialogExpired {
                closeDialog(at: i, reason: "本对话已超过 6 小时，已自动关闭。如需再次咨询，请发起新的提问。")
                changed = true
            }
        }
        if changed { bump() }
    }

    private func closeDialog(at index: Int, reason: String) {
        guard consultations[index].status == .active else { return }
        consultations[index].status = .closed
        consultations[index].closedAt = .now
        consultations[index].messages.append(
            ChatMessage(id: UUID().uuidString, sender: .system, text: "⏰ \(reason)", createdAt: .now)
        )
    }

    @discardableResult
    func endDialogEarly(id: String) -> Result<Void, ConsultationError> {
        processTimeouts()
        guard let index = consultations.firstIndex(ofId: id) else {
            return .failure(.message("未找到该咨询"))
        }
        guard consultations[index].status == .active else {
            return .failure(.message("当前状态无法结束对话"))
        }
        closeDialog(at: index, reason: "您已提前结束对话。如需再次咨询，请发起新的提问。")
        unreadConsultationIds.remove(id)
        saveUnread()
        bump()
        updatePatientBadge()
        return .success(())
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Consultation].self, from: data) else {
            consultations = []
            return
        }
        consultations = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(consultations) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

private extension Array where Element == Consultation {
    func firstIndex(ofId id: String) -> Int? {
        firstIndex { $0.id == id }
    }
}
