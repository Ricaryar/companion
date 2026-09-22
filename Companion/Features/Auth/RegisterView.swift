import SwiftUI

struct RegisterView: View {
    let initialRole: AccountRole

    @State private var accountStore = AccountStore.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    private var isDoctorFlow: Bool { initialRole == .doctor }

    var body: some View {
        Form {
            Section {
                Text(isDoctorFlow ? "注册医生账号并提交认证材料，审核通过后即可使用医生端功能。" : "注册普通用户账号，使用提问、方案与病历等患者功能。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("账号信息") {
                TextField("邮箱", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                SecureField("密码（至少 6 位）", text: $password)
                    .textContentType(.newPassword)
                SecureField("确认密码", text: $confirmPassword)
                    .textContentType(.newPassword)
            }

            Section {
                Button(isDoctorFlow ? "注册并前往医生认证" : "注册并登录") {
                    register()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(isDoctorFlow ? "医生账号注册" : "用户注册")
        .navigationBarTitleDisplayMode(.inline)
        .alert("无法注册", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func register() {
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        let result = accountStore.register(email: email, password: password, role: initialRole)
        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView(initialRole: .patient)
    }
}
