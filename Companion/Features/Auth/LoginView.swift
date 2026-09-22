import SwiftUI

struct LoginView: View {
    @State private var accountStore = AccountStore.shared
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.brandTeal)
                    Text("登录伴行")
                        .font(.title.bold())
                    Text("记录治疗与随访，向医生提问获取帮助")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(spacing: 14) {
                    TextField("邮箱", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)

                    SecureField("密码", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)

                    Button("登录") {
                        login()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brandTeal)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    NavigationLink {
                        RegisterView(initialRole: .patient)
                    } label: {
                        Text("没有账号？立即注册")
                            .font(.subheadline)
                    }

                    NavigationLink {
                        RegisterView(initialRole: .doctor)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.text.rectangle")
                            Text("医生认证点击此处")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(AppTheme.brandIndigo)
                    }
                    .padding(.top, 4)

                    Text("医生账号注册后将进入认证流程，审核通过后可接诊回答。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer(minLength: 24)
            }
        }
        .background(AppTheme.screenBackground)
        .navigationBarTitleDisplayMode(.inline)
        .alert("无法登录", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear { _ = accountStore.changeToken }
    }

    private func login() {
        let result = accountStore.login(email: email, password: password)
        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
