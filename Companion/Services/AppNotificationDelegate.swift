import Foundation
import UserNotifications

/// 咨询相关深度链接与通知点击路由。
@Observable
final class ConsultationDeepLink {
    static let shared = ConsultationDeepLink()

    /// 切换到「提问」Tab
    var shouldSelectAskTab = false
    /// 切换到「设置」Tab（患者端遗留路由名）
    var shouldSelectMoreTab = false
    /// 医生端：打开工作台内咨询
    var shouldOpenDoctorWorkspace = false
    /// 打开指定咨询对话（患者）
    var pendingChatId: String?
    /// 打开指定咨询对话（医生）
    var pendingDoctorChatId: String?

    func openChat(consultationId: String) {
        pendingChatId = consultationId
        shouldSelectAskTab = true
    }

    func openDoctorChat(consultationId: String) {
        pendingDoctorChatId = consultationId
        if AccountStore.shared.isDoctorSession {
            shouldOpenDoctorWorkspace = true
        } else {
            shouldSelectMoreTab = true
        }
    }

    func consumePendingChatId() -> String? {
        let id = pendingChatId
        pendingChatId = nil
        return id
    }

    func consumePendingDoctorChatId() -> String? {
        let id = pendingDoctorChatId
        pendingDoctorChatId = nil
        return id
    }
}

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let type = info[NotificationScheduler.notificationTypeKey] as? String,
           type == NotificationScheduler.doctorFollowUpType,
           let id = info[NotificationScheduler.consultationIdKey] as? String {
            DispatchQueue.main.async {
                ConsultationDeepLink.shared.openDoctorChat(consultationId: id)
            }
        } else if let id = info[NotificationScheduler.consultationIdKey] as? String {
            DispatchQueue.main.async {
                ConsultationDeepLink.shared.openChat(consultationId: id)
            }
        }
        completionHandler()
    }
}
