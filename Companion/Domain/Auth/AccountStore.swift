import Foundation

@Observable
final class AccountStore {
    static let shared = AccountStore()

    private(set) var accounts: [UserAccount] = []
    private(set) var currentUser: UserAccount?
    private(set) var changeToken = 0

    private let defaults = UserDefaults.standard
    private let accountsKey = "auth.accounts"
    private let sessionUserIdKey = "auth.sessionUserId"

    private init() {
        load()
    }

    var isLoggedIn: Bool {
        _ = changeToken
        return currentUser != nil
    }

    var isDoctorSession: Bool {
        currentUser?.role == .doctor
    }

    private func bump() {
        changeToken += 1
    }

    private func load() {
        if let data = defaults.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([UserAccount].self, from: data) {
            accounts = decoded
        } else {
            accounts = []
        }
        if let id = defaults.string(forKey: sessionUserIdKey) {
            currentUser = accounts.first { $0.id == id }
        } else {
            currentUser = nil
        }
    }

    private func saveAccounts() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        defaults.set(data, forKey: accountsKey)
        bump()
    }

    private func saveSession() {
        if let id = currentUser?.id {
            defaults.set(id, forKey: sessionUserIdKey)
        } else {
            defaults.removeObject(forKey: sessionUserIdKey)
        }
        bump()
    }

    @discardableResult
    func register(email: String, password: String, role: AccountRole) -> Result<UserAccount, AccountError> {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedEmail.contains("@"), trimmedEmail.count >= 5 else {
            return .failure(.message("请输入有效的邮箱地址"))
        }
        guard trimmedPassword.count >= 6 else {
            return .failure(.message("密码至少 6 位"))
        }
        if accounts.contains(where: { $0.email == trimmedEmail }) {
            return .failure(.message("该邮箱已注册"))
        }

        let account = UserAccount(
            id: UUID().uuidString,
            email: trimmedEmail,
            password: trimmedPassword,
            role: role,
            createdAt: .now
        )
        accounts.append(account)
        saveAccounts()
        currentUser = account
        saveSession()
        return .success(account)
    }

    @discardableResult
    func login(email: String, password: String) -> Result<UserAccount, AccountError> {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let account = accounts.first(where: { $0.email == trimmedEmail }) else {
            return .failure(.message("账号不存在，请先注册"))
        }
        guard account.password == trimmedPassword else {
            return .failure(.message("密码错误"))
        }
        currentUser = account
        saveSession()
        return .success(account)
    }

    func logout() {
        currentUser = nil
        saveSession()
    }
}
