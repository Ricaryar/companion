import SwiftUI
import SwiftData

struct CalendarHistoryView: View {
    @Query(sort: \ScheduleEvent.plannedAt) private var events: [ScheduleEvent]
    @Query(sort: \SymptomLog.date, order: .reverse) private var checkIns: [SymptomLog]
    @Query(sort: \RegimenInstance.startDate) private var regimens: [RegimenInstance]
    @Query(sort: \MedicalReport.reportDate, order: .reverse) private var reports: [MedicalReport]

    @State private var selectedDate = Date.now
    @State private var displayedMonth = Date.now

    private var monthData: CalendarMonthData {
        CalendarHistoryAggregator.monthData(
            for: displayedMonth,
            events: events,
            checkIns: checkIns,
            regimens: regimens
        )
    }

    private var daySummary: CalendarDaySummary {
        CalendarHistoryAggregator.summary(
            for: selectedDate,
            events: events,
            checkIns: checkIns,
            regimens: regimens
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    achievementsBanner
                    MonthCalendarGrid(
                        monthData: monthData,
                        selectedDate: $selectedDate,
                        displayedMonth: $displayedMonth
                    )

                    dayDetailSection
                }
                .padding(.vertical)
            }
            .background(AppTheme.screenBackground)
            .navigationTitle(CopyStrings.treatmentCalendar)
        }
    }

    private var achievementsBanner: some View {
        let ach = monthData.achievements
        return HStack(spacing: 16) {
            achievementStat(value: "\(ach.checkInDays)", label: "打卡天")
            achievementStat(value: "\(ach.completedTasks)", label: "完成任务")
            achievementStat(value: "\(ach.currentStreak)", label: "连续天")
            achievementStat(value: "\(ach.journeyDays)", label: "伴行天")
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .padding(.horizontal)
    }

    private func achievementStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.brandTeal)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var dayDetailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate, format: .dateTime.year().month().day().weekday(.wide))
                .font(.headline)
                .padding(.horizontal)

            if !daySummary.hasActivity {
                Text("该日暂无记录")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if let checkIn = daySummary.checkIn {
                sectionCard(title: CopyStrings.checkIn, icon: "face.smiling") {
                    HStack {
                        Text(checkIn.riskLevel.displayName)
                            .foregroundStyle(RiskLevelColor.color(for: checkIn.riskLevel))
                        Text("疼痛 \(checkIn.pain)/10")
                        if let fever = checkIn.fever {
                            Text(String(format: "%.1f℃", fever))
                        }
                    }
                    .font(.caption)
                }
            }

            if !daySummary.events.isEmpty {
                sectionCard(title: "治疗日程", icon: "calendar.badge.clock") {
                    ForEach(daySummary.events) { event in
                        HStack {
                            Image(systemName: event.status == .done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(event.status == .done ? AppTheme.riskGreen : .secondary)
                            Text(event.title)
                            Spacer()
                            Text(event.status.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !daySummary.milestones.isEmpty {
                sectionCard(title: "里程碑", icon: "flag.fill") {
                    ForEach(daySummary.milestones) { milestone in
                        Text(milestone.title)
                    }
                }
            }

            let dayReports = reports.filter { Calendar.current.isDate($0.reportDate, inSameDayAs: selectedDate) }
            if !dayReports.isEmpty {
                sectionCard(title: "检验报告", icon: "doc.text") {
                    ForEach(dayReports) { report in
                        NavigationLink {
                            ReportDetailView(report: report)
                        } label: {
                            Text(report.title)
                        }
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .padding(.horizontal)
    }
}

#Preview {
    CalendarHistoryView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
