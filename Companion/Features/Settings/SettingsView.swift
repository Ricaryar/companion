import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("打卡与提醒") {
                    Picker("打卡偏好", selection: Binding(
                        get: { settings.checkInPreference },
                        set: { settings.checkInPreference = $0 }
                    )) {
                        ForEach(CheckInTimePreference.allCases, id: \.self) { pref in
                            Text(pref.label).tag(pref)
                        }
                    }
                    Toggle("合并同时段提醒", isOn: Binding(
                        get: { settings.mergeReminders },
                        set: { settings.mergeReminders = $0 }
                    ))
                }

                Section("显示") {
                    Toggle("布里斯托分型说明", isOn: Binding(
                        get: { settings.showBristolGuide },
                        set: { settings.showBristolGuide = $0 }
                    ))
                    Toggle("检验对齐周期", isOn: Binding(
                        get: { settings.alignLabsToCycle },
                        set: { settings.alignLabsToCycle = $0 }
                    ))
                }

                Section("医疗数据") {
                    NavigationLink("管理检验指标") {
                        ManageLabMetricsView()
                    }
                    NavigationLink("参考范围设置") {
                        LabReferenceSettingsView()
                    }
                    NavigationLink("指标趋势") {
                        LabTrendsView()
                    }
                }

                Section("导出") {
                    NavigationLink("就医准备") {
                        DoctorPrepView()
                    }
                    NavigationLink("导出摘要") {
                        ExportSummaryView()
                    }
                }

                Section("关于") {
                    LabeledContent("应用", value: CopyStrings.appNameZH)
                    LabeledContent("版本", value: "1.0.0")
                    Button("重新查看引导") {
                        settings.hasCompletedOnboarding = false
                    }
                }

            Section {
                DisclaimerFooter()
            }
        }
        .navigationTitle("设置")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
