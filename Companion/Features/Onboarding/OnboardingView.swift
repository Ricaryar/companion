import SwiftUI

struct OnboardingView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var currentPage = 0
    @State private var checkInPreference: CheckInTimePreference = .morning

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("heart.circle.fill", CopyStrings.onboardingTitle, CopyStrings.onboardingSubtitle),
        ("pills.fill", "方案与日程", "从模板添加治疗方案，自动生成周期日程与提醒。"),
        ("doc.text.viewfinder", "智能识别报告", "拍照上传检验报告，自动识别 CEA、CA199 等指标。"),
        ("chart.line.uptrend.xyaxis", "趋势与就医准备", "追踪指标变化，一键导出摘要供就诊使用。")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: page.icon)
                            .font(.system(size: 72))
                            .foregroundStyle(AppTheme.brandTeal)
                        Text(page.title)
                            .font(.title.bold())
                        Text(page.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if currentPage == pages.count - 1 {
                VStack(spacing: 16) {
                    Picker("打卡偏好", selection: $checkInPreference) {
                        ForEach(CheckInTimePreference.allCases, id: \.self) { pref in
                            Text(pref.label).tag(pref)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button("开始使用") {
                        settings.checkInPreference = checkInPreference
                        settings.hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brandTeal)
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            } else {
                Button("下一步") {
                    withAnimation { currentPage += 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brandTeal)
                .padding(.bottom, 32)
            }

            DisclaimerFooter()
        }
    }
}

#Preview {
    OnboardingView()
}
