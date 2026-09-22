import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<RegimenInstance> { $0.isActive }, sort: \RegimenInstance.createdAt, order: .reverse)
    private var activeRegimens: [RegimenInstance]
    @Query(sort: \SymptomLog.date, order: .reverse) private var symptomLogs: [SymptomLog]
    @Query(sort: \MedicalReport.reportDate, order: .reverse) private var reports: [MedicalReport]
    @Query(sort: \ScheduleEvent.plannedAt) private var allEvents: [ScheduleEvent]

    @State private var showSymptomCheckIn = false
    @State private var healthBeans = HealthBeansStore.shared

    private var todayEvents: [ScheduleEvent] {
        let cal = Calendar.current
        return allEvents.filter { cal.isDateInToday($0.plannedAt) && $0.status != .skipped }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    quickActionsSection
                    myRegimenSection
                    todayTasksSection
                    recentSymptomSection
                    recentReportsSection
                    DisclaimerFooter()
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("首页")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HealthTasksView()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(.orange)
                            Text("\(healthBeans.balance)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityLabel("健康豆 \(healthBeans.balance)")
                    }
                }
            }
            .onAppear { healthBeans.rollDayIfNeeded() }
            .sheet(isPresented: $showSymptomCheckIn) {
                SymptomCheckInView()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.title2.bold())
            Text(Date.now, format: .dateTime.year().month().day().weekday(.wide))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "早上好"
        case 12..<18: timeGreeting = "下午好"
        default: timeGreeting = "晚上好"
        }
        return timeGreeting
    }

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                quickActionButton(icon: "face.smiling", title: CopyStrings.checkIn, color: .purple) {
                    showSymptomCheckIn = true
                }
                NavigationLink {
                    AddReportView()
                } label: {
                    quickActionLabel(icon: "camera.fill", title: CopyStrings.addReport, color: AppTheme.brandIndigo)
                }
                NavigationLink {
                    DoctorPrepView()
                } label: {
                    quickActionLabel(icon: "person.2.wave.2", title: "就医准备", color: AppTheme.brandTeal)
                }
            }

            HStack(spacing: 12) {
                NavigationLink {
                    DocumentsLibraryView(
                        navigationTitle: "文件",
                        showMedicalShortcuts: true
                    )
                } label: {
                    quickActionLabel(icon: "folder.fill", title: "文件", color: .orange)
                }
                NavigationLink {
                    MedicationShareCommunityView()
                } label: {
                    quickActionLabel(icon: "pills.fill", title: "真实用药", color: AppTheme.riskGreen)
                }
            }
        }
    }

    private var myRegimenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的方案")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    AddRegimenWizardView()
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.subheadline)
                }
                NavigationLink {
                    RegimenTabView()
                } label: {
                    Text("管理")
                        .font(.subheadline)
                }
            }

            if activeRegimens.isEmpty {
                Text(CopyStrings.emptyRegimen)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .companionCard()
            } else {
                ForEach(activeRegimens) { regimen in
                    NavigationLink {
                        SideEffectTipsView(regimen: regimen)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(regimen.displayName)
                                .font(.subheadline.bold())
                            Text("\(regimen.line.displayName) · 第 \(regimen.currentCycleIndex) 周期")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .companionCard()
                }

                if !activeRegimens.isEmpty {
                    NavigationLink {
                        SideEffectTipsView(activeRegimens: activeRegimens)
                    } label: {
                        Label("查看全部副作用提示", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func quickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionLabel(icon: icon, title: title, color: color)
        }
        .buttonStyle(.plain)
    }

    private func quickActionLabel(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .companionCard()
    }

    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CopyStrings.todayTasks)
                .font(.headline)

            if todayEvents.isEmpty {
                Text("今日暂无待办事项。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .companionCard()
            } else {
                ForEach(todayEvents) { event in
                    todayEventRow(event)
                }
            }
        }
    }

    private func todayEventRow(_ event: ScheduleEvent) -> some View {
        HStack {
            Button {
                ScheduleEventActions.toggleCompletion(event, context: modelContext)
            } label: {
                Image(systemName: event.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(event.status == .done ? AppTheme.riskGreen : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.bold())
                    .strikethrough(event.status == .done, color: .secondary)
                Text(event.plannedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(event.status.displayName)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusBadgeColor(for: event.status).opacity(0.15))
                .foregroundStyle(statusBadgeColor(for: event.status))
        }
        .companionCard()
    }

    private func statusBadgeColor(for status: ScheduleEventStatus) -> Color {
        switch status {
        case .done: AppTheme.riskGreen
        case .pending, .deferred: AppTheme.brandTeal
        case .skipped: .secondary
        }
    }

    private var recentSymptomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近打卡")
                .font(.headline)

            if let latest = symptomLogs.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(latest.date, format: .dateTime.month().day())
                        Spacer()
                        Text(latest.riskLevel.displayName)
                            .font(.caption.bold())
                            .foregroundStyle(RiskLevelColor.color(for: latest.riskLevel))
                    }
                    HStack(spacing: 16) {
                        Label("疼痛 \(latest.pain)/10", systemImage: "bandage")
                        if let fever = latest.fever {
                            Label(String(format: "%.1f℃", fever), systemImage: "thermometer")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .companionCard()
            } else {
                Text("尚未打卡，点击「\(CopyStrings.checkIn)」开始。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .companionCard()
            }
        }
    }

    private var recentReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(CopyStrings.recentReports)
                    .font(.headline)
                Spacer()
                NavigationLink("全部文件") {
                    DocumentsLibraryView(navigationTitle: "文件")
                }
                .font(.subheadline)
            }

            if reports.isEmpty {
                Text("暂无报告，可在「文件」或「就医文件」中上传。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .companionCard()
            } else {
                ForEach(reports.prefix(2)) { report in
                    NavigationLink {
                        ReportDetailView(report: report)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(report.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                HStack(spacing: 4) {
                                    Text(report.reportType.displayName)
                                    Text("·")
                                    Text(report.reportDate, format: .dateTime.year().month().day())
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if report.reportType == .lab {
                                Text("\(report.labResults.count) 项")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .companionCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
