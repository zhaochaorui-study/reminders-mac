import SwiftUI

private enum SchedulePickerLayout {
    static let expandedWidth: CGFloat = 266
    static let recurringWidth: CGFloat = 220
    static let outerSpacing: CGFloat = 5
    static let outerPadding: CGFloat = 5
    static let sectionSpacing: CGFloat = 5
    static let sectionPadding: CGFloat = 6
    static let weekdaySpacing: CGFloat = 2
    static let dayCellHeight: CGFloat = 21
    static let navButtonSize: CGFloat = 18
    static let timeRowSpacing: CGFloat = 4
    static let timeChipHeight: CGFloat = 34
    static let stepperButtonWidth: CGFloat = 12
    static let stepperButtonHeight: CGFloat = 10
    static let timeIconSize: CGFloat = 14
}

struct ScheduleDateTimePickerView: View {
    @Binding var selection: Date
    let minimumDate: Date
    let isRecurringMode: Bool
    let onConfirm: () -> Void

    @State private var displayedMonth: Date
    @ObservedObject private var themeManager = ThemeManager.shared

    private var calendar: Calendar { Calendar.autoupdatingCurrent }
    private var appearance: SchedulePickerAppearance { SchedulePickerAppearance(isCandyTheme: themeManager.isCandyTheme) }
    private var monthTitle: String { SchedulePickerFormatters.month.string(from: displayedMonth) }
    private var timeText: String { SchedulePickerFormatters.time.string(from: selection) }
    private var weekdaySymbols: [String] { Self.rotatedWeekdaySymbols(calendar: calendar) }
    private var monthDays: [ScheduleDay] { makeMonthDays() }
    private var canGoToPreviousMonth: Bool { canNavigateBackFromCurrentMonth() }
    private var pickerWidth: CGFloat {
        isRecurringMode ? SchedulePickerLayout.recurringWidth : SchedulePickerLayout.expandedWidth
    }

    init(
        selection: Binding<Date>,
        minimumDate: Date,
        isRecurringMode: Bool,
        onConfirm: @escaping () -> Void
    ) {
        self._selection = selection
        self.minimumDate = minimumDate
        self.isRecurringMode = isRecurringMode
        self.onConfirm = onConfirm
        _displayedMonth = State(initialValue: Self.startOfMonth(for: selection.wrappedValue))
    }

    var body: some View {
        VStack(spacing: SchedulePickerLayout.outerSpacing) {
            if !isRecurringMode {
                ScheduleCalendarSectionView(
                    monthTitle: monthTitle,
                    weekdaySymbols: weekdaySymbols,
                    days: monthDays,
                    appearance: appearance,
                    selectedDate: selection,
                    canGoToPreviousMonth: canGoToPreviousMonth,
                    onPreviousMonth: previousMonth,
                    onNextMonth: nextMonth,
                    onSelectDay: selectDay
                )
            }

            ScheduleTimeControlRow(
                timeText: timeText,
                appearance: appearance,
                onIncrementMinute: { adjustTime(by: 1) },
                onDecrementMinute: { adjustTime(by: -1) },
                onConfirm: onConfirm
            )
        }
        .padding(SchedulePickerLayout.outerPadding)
        .background(
            appearance.outerSurface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(appearance.border, lineWidth: 0.8)
        }
        .shadow(color: appearance.shadow, radius: 12, x: 0, y: 5)
        .frame(width: pickerWidth)
        .onAppear {
            displayedMonth = Self.startOfMonth(for: selection)
            if selection < minimumDate {
                selection = minimumDate
            }
        }
        .onChange(of: selection) { _, newValue in
            let newMonth = Self.startOfMonth(for: newValue)
            guard !calendar.isDate(newMonth, equalTo: displayedMonth, toGranularity: .month) else { return }
            displayedMonth = newMonth
        }
    }

    private func previousMonth() {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        guard canNavigate(to: previousMonth) else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            displayedMonth = Self.startOfMonth(for: previousMonth)
        }
    }

    private func nextMonth() {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            displayedMonth = Self.startOfMonth(for: nextMonth)
        }
    }

    private func selectDay(_ day: Date) {
        let candidate = composeDate(
            from: day,
            preservingTimeFrom: selection
        )

        updateSelection(candidate)

        let targetMonth = Self.startOfMonth(for: day)
        guard !calendar.isDate(targetMonth, equalTo: displayedMonth, toGranularity: .month) else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            displayedMonth = targetMonth
        }
    }

    private func adjustTime(by minuteDelta: Int) {
        guard let candidate = calendar.date(byAdding: .minute, value: minuteDelta, to: selection) else { return }
        updateSelection(candidate)
    }

    private func updateSelection(_ candidate: Date) {
        let clamped = max(candidate, minimumDate)
        guard clamped != selection else { return }
        selection = clamped
    }

    private func composeDate(from date: Date, preservingTimeFrom source: Date) -> Date {
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: source)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second ?? 0
        return calendar.date(from: dateComponents) ?? date
    }

    private func makeMonthDays() -> [ScheduleDay] {
        let monthStart = Self.startOfMonth(for: displayedMonth)
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { return [] }

        let startWeekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (startWeekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) else { return [] }

        let minimumSelectableDay = calendar.startOfDay(for: minimumDate)

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            let normalizedDay = calendar.startOfDay(for: date)

            return ScheduleDay(
                date: normalizedDay,
                isCurrentMonth: monthInterval.contains(date),
                isSelectable: normalizedDay >= minimumSelectableDay
            )
        }
    }

    private func canNavigateBackFromCurrentMonth() -> Bool {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return false }
        return canNavigate(to: previousMonth)
    }

    private func canNavigate(to month: Date) -> Bool {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return false }
        return interval.end > minimumDate
    }

    private static func startOfMonth(for date: Date) -> Date {
        Calendar.autoupdatingCurrent.dateInterval(of: .month, for: date)?.start ?? date
    }

    private static func rotatedWeekdaySymbols(calendar: Calendar) -> [String] {
        let baseSymbols = ["日", "一", "二", "三", "四", "五", "六"]
        let offset = max(calendar.firstWeekday - 1, 0) % baseSymbols.count
        guard offset > 0 else { return baseSymbols }
        return Array(baseSymbols[offset...] + baseSymbols[..<offset])
    }
}

private struct ScheduleCalendarSectionView: View {
    let monthTitle: String
    let weekdaySymbols: [String]
    let days: [ScheduleDay]
    let appearance: SchedulePickerAppearance
    let selectedDate: Date
    let canGoToPreviousMonth: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: SchedulePickerLayout.sectionSpacing) {
            HStack(spacing: SchedulePickerLayout.sectionSpacing) {
                Text(monthTitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(appearance.monthText)

                Spacer()

                HStack(spacing: 5) {
                    CalendarNavButton(
                        systemName: "chevron.left",
                        appearance: appearance,
                        isEnabled: canGoToPreviousMonth,
                        action: onPreviousMonth
                    )

                    CalendarNavButton(
                        systemName: "chevron.right",
                        appearance: appearance,
                        isEnabled: true,
                        action: onNextMonth
                    )
                }
            }

            LazyVGrid(columns: columns, spacing: SchedulePickerLayout.weekdaySpacing) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(appearance.weekdayText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            LazyVGrid(columns: columns, spacing: SchedulePickerLayout.weekdaySpacing) {
                ForEach(days) { day in
                    CalendarDayCellView(
                        day: day,
                        appearance: appearance,
                        isSelected: Calendar.autoupdatingCurrent.isDate(day.date, inSameDayAs: selectedDate),
                        isToday: Calendar.autoupdatingCurrent.isDateInToday(day.date),
                        onSelect: onSelectDay
                    )
                }
            }
        }
        .padding(SchedulePickerLayout.sectionPadding)
        .background(
            appearance.calendarSurface,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(appearance.border, lineWidth: 0.7)
        }
    }
}

private struct CalendarNavButton: View {
    let systemName: String
    let appearance: SchedulePickerAppearance
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(appearance.navText.opacity(isEnabled ? 1 : 0.35))
                .frame(
                    width: SchedulePickerLayout.navButtonSize,
                    height: SchedulePickerLayout.navButtonSize
                )
                .background(
                    appearance.navSurface.opacity(isEnabled ? 1 : 0.5),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(appearance.border.opacity(0.75), lineWidth: 0.6)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(systemName == "chevron.left" ? "上一个月" : "下一个月")
    }
}

private struct CalendarDayCellView: View {
    let day: ScheduleDay
    let appearance: SchedulePickerAppearance
    let isSelected: Bool
    let isToday: Bool
    let onSelect: (Date) -> Void

    var body: some View {
        Button(action: { onSelect(day.date) }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(appearance.selectedDayFill)
                        .shadow(color: appearance.shadow.opacity(0.3), radius: 3, x: 0, y: 1)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(appearance.todayRing, lineWidth: 1)
                }

                Text("\(Calendar.autoupdatingCurrent.component(.day, from: day.date))")
                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dayForeground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: SchedulePickerLayout.dayCellHeight)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!day.isSelectable)
        .opacity(dayOpacity)
        .accessibilityLabel(day.accessibilityLabel)
        .accessibilityHint(day.isSelectable ? "双击选择日期" : "当前日期早于可选范围")
    }

    private var dayForeground: Color {
        if isSelected {
            return appearance.selectedDayText
        }

        if day.isCurrentMonth {
            return day.isSelectable ? appearance.dayText : appearance.dayMutedText
        }

        return appearance.dayMutedText.opacity(0.7)
    }

    private var dayOpacity: Double {
        if isSelected {
            return 1
        }

        if day.isCurrentMonth {
            return day.isSelectable ? 1 : 0.38
        }

        return 0.55
    }
}

private struct ScheduleTimeControlRow: View {
    let timeText: String
    let appearance: SchedulePickerAppearance
    let onIncrementMinute: () -> Void
    let onDecrementMinute: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: SchedulePickerLayout.timeRowSpacing) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(appearance.weekdayText)
                .frame(
                    width: SchedulePickerLayout.timeIconSize,
                    height: SchedulePickerLayout.timeIconSize
                )

            HStack(spacing: 5) {
                Text(timeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(appearance.timeChipText)

                VStack(spacing: 2) {
                    StepperChevronButton(
                        systemName: "chevron.up",
                        appearance: appearance,
                        action: onIncrementMinute
                    )

                    StepperChevronButton(
                        systemName: "chevron.down",
                        appearance: appearance,
                        action: onDecrementMinute
                    )
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 2)
                .background(
                    appearance.stepperSurface,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
            }
            .padding(.horizontal, 8)
            .frame(height: SchedulePickerLayout.timeChipHeight)
            .background(
                appearance.timeChipFill,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(appearance.border.opacity(0.35), lineWidth: 0.8)
            }

            Spacer(minLength: 0)

            Button(action: onConfirm) {
                Text("确定")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(appearance.confirmText)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 2)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StepperChevronButton: View {
    let systemName: String
    let appearance: SchedulePickerAppearance
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(appearance.stepperText)
                .frame(
                    width: SchedulePickerLayout.stepperButtonWidth,
                    height: SchedulePickerLayout.stepperButtonHeight
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "chevron.up" ? "增加 1 分钟" : "减少 1 分钟")
    }
}

private struct SchedulePickerAppearance {
    let outerSurface: Color
    let calendarSurface: Color
    let border: Color
    let monthText: Color
    let weekdayText: Color
    let dayText: Color
    let dayMutedText: Color
    let selectedDayFill: Color
    let selectedDayText: Color
    let todayRing: Color
    let navSurface: Color
    let navText: Color
    let timeChipFill: Color
    let timeChipText: Color
    let stepperSurface: Color
    let stepperText: Color
    let confirmText: Color
    let shadow: Color

    init(isCandyTheme: Bool) {
        if isCandyTheme {
            self.outerSurface = Color(hex: 0xE6DECE)
            self.calendarSurface = Color(hex: 0xECE4D6)
            self.border = Color(hex: 0xD2C8BA, opacity: 0.85)
            self.monthText = Color(hex: 0x28322D)
            self.weekdayText = Color(hex: 0x66736A)
            self.dayText = Color(hex: 0x28322D)
            self.dayMutedText = Color(hex: 0x98A197)
            self.selectedDayFill = Color(hex: 0x303338)
            self.selectedDayText = Color(hex: 0xF6F0E6)
            self.todayRing = Color(hex: 0x5A82AF, opacity: 0.45)
            self.navSurface = Color(hex: 0xDBD1C1)
            self.navText = Color(hex: 0x66736A)
            self.timeChipFill = Color(hex: 0xF3EBDc)
            self.timeChipText = Color(hex: 0x2B3430)
            self.stepperSurface = Color(hex: 0xE2D7C5)
            self.stepperText = Color(hex: 0x617066)
            self.confirmText = Color(hex: 0x5A82AF)
            self.shadow = Color(hex: 0x8A715D, opacity: 0.18)
        } else {
            self.outerSurface = Color(hex: 0x2C2C2E)
            self.calendarSurface = Color(hex: 0x3A3A3C)
            self.border = Color(hex: 0x38383A, opacity: 0.9)
            self.monthText = .white
            self.weekdayText = Color(hex: 0x8E8E93)
            self.dayText = .white
            self.dayMutedText = Color(hex: 0x636366)
            self.selectedDayFill = Color(hex: 0x0A84FF)
            self.selectedDayText = .white
            self.todayRing = Color(hex: 0xFF9F0A, opacity: 0.55)
            self.navSurface = Color(hex: 0x2C2C2E)
            self.navText = .white
            self.timeChipFill = Color(hex: 0x3A3A3C)
            self.timeChipText = .white
            self.stepperSurface = Color(hex: 0x252528)
            self.stepperText = Color(hex: 0x8E8E93)
            self.confirmText = Color(hex: 0x0A84FF)
            self.shadow = Color.black.opacity(0.28)
        }
    }
}

private struct ScheduleDay: Identifiable {
    let date: Date
    let isCurrentMonth: Bool
    let isSelectable: Bool

    var id: Date { date }

    var accessibilityLabel: String {
        SchedulePickerFormatters.accessibilityDate.string(from: date)
    }
}

private enum SchedulePickerFormatters {
    static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let accessibilityDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter
    }()
}
