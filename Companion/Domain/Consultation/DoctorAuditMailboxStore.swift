import Foundation

struct AuditMailMessage: Codable, Identifiable, Equatable {
    var id: String
    var accountId: String
    var subject: String
    var body: String
    var createdAt: Date
    var isRead: Bool
}

@Observable
final class DoctorAuditMailboxStore {
    static let shared = DoctorAuditMailboxStore()

    private(set) var messages: [AuditMailMessage] = []
    private(set) var changeToken = 0

    private let defaults = UserDefaults.standard
    private let key = "doctor.audit.mailbox"

    private init() {
        load()
    }

    private func bump() {
        changeToken += 1
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AuditMailMessage].self, from: data) else {
            messages = []
            return
        }
        messages = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        defaults.set(data, forKey: key)
        bump()
    }

    func messages(for accountId: String) -> [AuditMailMessage] {
        _ = changeToken
        return messages
            .filter { $0.accountId == accountId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func unreadCount(for accountId: String) -> Int {
        messages(for: accountId).filter { !$0.isRead }.count
    }

    func markRead(id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].isRead = true
        save()
    }

    func markAllRead(accountId: String) {
        var changed = false
        for index in messages.indices where messages[index].accountId == accountId && !messages[index].isRead {
            messages[index].isRead = true
            changed = true
        }
        if changed { save() }
    }

    func post(accountId: String, subject: String, body: String) {
        let msg = AuditMailMessage(
            id: UUID().uuidString,
            accountId: accountId,
            subject: subject,
            body: body,
            createdAt: .now,
            isRead: false
        )
        messages.insert(msg, at: 0)
        save()
    }

    func notifyCertSubmitted(accountId: String, realName: String) {
        post(
            accountId: accountId,
            subject: "医生认证申请已收到",
            body: """
            \(realName) 您好，

            我们已收到您的医生认证材料，平台将在 1–3 个工作日内完成审核。审核结果将发送至本邮箱。

            审核期间您可以查看患者提问，但暂无法接诊回复。请耐心等待。
            """
        )
    }

    func notifyCertApproved(accountId: String, realName: String) {
        post(
            accountId: accountId,
            subject: "医生认证审核通过",
            body: """
            \(realName) 您好，

            恭喜，您的医生认证已通过。您现在可以在「回答患者问题」中接诊并回复患者。

            请遵守平台规范，为患者提供专业、负责的健康咨询。
            """
        )
    }

    func notifyCertRejected(accountId: String, realName: String, reason: String) {
        post(
            accountId: accountId,
            subject: "医生认证未通过",
            body: """
            \(realName) 您好，

            很抱歉，本次医生认证未通过审核。

            原因：\(reason)

            您可补充材料后重新提交认证申请。
            """
        )
    }
}
