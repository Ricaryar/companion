import SwiftUI

enum AppTheme {
    static let brandTeal = Color(red: 0.22, green: 0.62, blue: 0.60)
    static let brandIndigo = Color(red: 0.28, green: 0.35, blue: 0.55)
    static let brandGraphite = Color(red: 0.35, green: 0.37, blue: 0.40)

    static let riskGreen = Color(red: 0.30, green: 0.65, blue: 0.45)
    static let riskYellow = Color(red: 0.90, green: 0.72, blue: 0.20)
    static let riskRed = Color(red: 0.85, green: 0.35, blue: 0.32)

    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let screenBackground = Color(.systemGroupedBackground)

    static let cornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 16
}

struct RiskLevelColor {
    static func color(for level: RiskLevel) -> Color {
        switch level {
        case .green: AppTheme.riskGreen
        case .yellow: AppTheme.riskYellow
        case .red: AppTheme.riskRed
        }
    }
}

struct CompanionCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}

extension View {
    func companionCard() -> some View {
        modifier(CompanionCardStyle())
    }
}
