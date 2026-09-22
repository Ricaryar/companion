import Foundation

enum AccountRole: String, Codable, CaseIterable {
    case patient
    case doctor

    var label: String {
        switch self {
        case .patient: "普通用户"
        case .doctor: "医生用户"
        }
    }
}

struct UserAccount: Codable, Identifiable, Equatable {
    var id: String
    var email: String
    var password: String
    var role: AccountRole
    var createdAt: Date
}

enum AccountError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}
