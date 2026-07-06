import SwiftUI

struct DisclaimerFooter: View {
    var body: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.riskYellow)
                    .font(.caption)
                Text(CopyStrings.disclaimerGlobal)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    DisclaimerFooter()
}
