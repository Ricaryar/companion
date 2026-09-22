import SwiftUI

struct AuthContainerView: View {
    var body: some View {
        NavigationStack {
            LoginView()
        }
        .tint(AppTheme.brandTeal)
    }
}

#Preview {
    AuthContainerView()
}
