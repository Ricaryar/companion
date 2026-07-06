import SwiftUI

struct MonthCalendarGrid: View {
    let monthData: CalendarMonthData
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let cellHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            daysGrid
        }
        .padding()
        .companionCard()
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(displayedMonth, format: .dateTime.year().month(.wide))
                .font(.headline)
            Spacer()
            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
            }
        }
    }

    private var daysGrid: some View {
        let days = daysInMonth()
        let leadingBlanks = firstWeekdayOfMonth()

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: cellHeight)
            }
            ForEach(days, id: \.self) { day in
                dayCell(for: day)
                    .frame(height: cellHeight)
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let start = calendar.startOfDay(for: date)
        let summary = monthData.summariesByDay[start]
        let activityLevel = summary?.activityLevel ?? 0
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                activityDot(level: activityLevel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AppTheme.brandTeal.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? AppTheme.brandTeal : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func activityDot(level: Int) -> some View {
        if level > 0 {
            Circle()
                .fill(activityColor(level))
                .frame(width: 5, height: 5)
        } else {
            Color.clear.frame(width: 5, height: 5)
        }
    }

    private func activityColor(_ level: Int) -> Color {
        switch level {
        case 3: AppTheme.riskGreen
        case 2: AppTheme.brandTeal
        default: AppTheme.brandIndigo.opacity(0.6)
        }
    }

    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
    }

    private func firstWeekdayOfMonth() -> Int {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return 0 }
        return calendar.component(.weekday, from: startOfMonth) - 1
    }

    private func shiftMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

#Preview {
    MonthCalendarGrid(
        monthData: CalendarHistoryAggregator.monthData(
            for: .now,
            events: [],
            checkIns: [],
            regimens: []
        ),
        selectedDate: .constant(.now),
        displayedMonth: .constant(.now)
    )
    .padding()
}
