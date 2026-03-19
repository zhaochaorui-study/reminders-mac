import SwiftUI

enum SchedulePickerSizeVariant {
    case regular
    case compact

    var metrics: SchedulePickerMetrics {
        switch self {
        case .regular:
            return SchedulePickerMetrics(
                expandedWidth: 266,
                recurringWidth: 220,
                outerSpacing: 5,
                outerPadding: 5,
                outerCornerRadius: 16,
                sectionSpacing: 5,
                sectionPadding: 6,
                sectionCornerRadius: 14,
                weekdaySpacing: 2,
                monthFontSize: 14,
                weekdayFontSize: 9,
                dayFontSize: 11,
                dayCellHeight: 21,
                dayCellCornerRadius: 8,
                navButtonSize: 18,
                navIconSize: 10,
                timeRowSpacing: 4,
                timeFontSize: 13,
                timeChipHeight: 34,
                timeChipCornerRadius: 11,
                stepperButtonWidth: 12,
                stepperButtonHeight: 10,
                stepperIconSize: 7,
                stepperCornerRadius: 7,
                timeIconSize: 14,
                confirmFontSize: 10
            )
        case .compact:
            return SchedulePickerMetrics(
                expandedWidth: 236,
                recurringWidth: 196,
                outerSpacing: 4,
                outerPadding: 4,
                outerCornerRadius: 14,
                sectionSpacing: 4,
                sectionPadding: 5,
                sectionCornerRadius: 12,
                weekdaySpacing: 1.5,
                monthFontSize: 13,
                weekdayFontSize: 8,
                dayFontSize: 10,
                dayCellHeight: 18,
                dayCellCornerRadius: 7,
                navButtonSize: 16,
                navIconSize: 9,
                timeRowSpacing: 3,
                timeFontSize: 12,
                timeChipHeight: 30,
                timeChipCornerRadius: 10,
                stepperButtonWidth: 10,
                stepperButtonHeight: 8,
                stepperIconSize: 6,
                stepperCornerRadius: 6,
                timeIconSize: 12,
                confirmFontSize: 9
            )
        }
    }
}

struct SchedulePickerMetrics {
    let expandedWidth: CGFloat
    let recurringWidth: CGFloat
    let outerSpacing: CGFloat
    let outerPadding: CGFloat
    let outerCornerRadius: CGFloat
    let sectionSpacing: CGFloat
    let sectionPadding: CGFloat
    let sectionCornerRadius: CGFloat
    let weekdaySpacing: CGFloat
    let monthFontSize: CGFloat
    let weekdayFontSize: CGFloat
    let dayFontSize: CGFloat
    let dayCellHeight: CGFloat
    let dayCellCornerRadius: CGFloat
    let navButtonSize: CGFloat
    let navIconSize: CGFloat
    let timeRowSpacing: CGFloat
    let timeFontSize: CGFloat
    let timeChipHeight: CGFloat
    let timeChipCornerRadius: CGFloat
    let stepperButtonWidth: CGFloat
    let stepperButtonHeight: CGFloat
    let stepperIconSize: CGFloat
    let stepperCornerRadius: CGFloat
    let timeIconSize: CGFloat
    let confirmFontSize: CGFloat
}

struct ScheduleDateTimePickerView: View {
    @Binding var selection: Date
    let minimumDate: Date
    let isRecurringMode: Bool
    let sizeVariant: SchedulePickerSizeVariant
    let onConfirm: () -> Void

    @State private var displayedMonth: Date
    @ObservedObject private var themeManager = ThemeManager.shared

    private var metrics: SchedulePickerMetrics { sizeVariant.metrics }
    private var calendar: Calendar { Calendar.autoupdatingCurrent }
    private var appearance: SchedulePickerAppearance { SchedulePickerAppearance(isCandyTheme: themeManager.isCandyTheme) }
    private var monthTitle: String { SchedulePickerFormatters.month.string(from: displayedMonth) }
    private var timeText: String { SchedulePickerFormatters.time.string(from: selection) }
    private var weekdaySymbols: [String] { Self.rotatedWeekdaySymbols(calendar: calendar) }
    private var monthDays: [ScheduleDay] { makeMonthDays() }
    private var canGoToPreviousMonth: Bool { canNavigateBackFromCurrentMonth() }
    private var pickerWidth: CGFloat {
        isRecurringMode ? metrics.recurringWidth : metrics.expandedWidth
    }

    init(
        selection: Binding<Date>,
        minimumDate: Date,
        isRecurringMode: Bool,
        sizeVariant: SchedulePickerSizeVariant = .regular,
        onConfirm: @escaping () -> Void
    ) {
        self._selection = selection
        self.minimumDate = minimumDate
        self.isRecurringMode = isRecurringMode
        self.sizeVariant = sizeVariant
        self.onConfirm = onConfirm
        _displayedMonth = State(initialValue: Self.startOfMonth(for: selection.wrappedValue))
    }

    var body: some View {
        VStack(spacing: metrics.outerSpacing) {
            if !isRecurringMode {
                ScheduleCalendarSectionView(
                    monthTitle: monthTitle,
                    weekdaySymbols: weekdaySymbols,
                    days: monthDays,
                    metrics: metrics,
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
                metrics: metrics,
                appearance: appearance,
                onIncrementMinute: { adjustTime(by: 1) },
                onDecrementMinute: { adjustTime(by: -1) },
                onConfirm: onConfirm
            )
        }
        .padding(metrics.outerPadding)
        .background(
            appearance.outerSurface,
            in: RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous)
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
    let metrics: SchedulePickerMetrics
    let appearance: SchedulePickerAppearance
    let selectedDate: Date
    let canGoToPreviousMonth: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: metrics.sectionSpacing) {
            HStack(spacing: metrics.sectionSpacing) {
                Text(monthTitle)
                    .font(.system(size: metrics.monthFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(appearance.monthText)

                Spacer()

                HStack(spacing: 5) {
                    CalendarNavButton(
                        systemName: "chevron.left",
                        metrics: metrics,
                        appearance: appearance,
                        isEnabled: canGoToPreviousMonth,
                        action: onPreviousMonth
                    )

                    CalendarNavButton(
                        systemName: "chevron.right",
                        metrics: metrics,
                        appearance: appearance,
                        isEnabled: true,
                        action: onNextMonth
                    )
                }
            }

            LazyVGrid(columns: columns, spacing: metrics.weekdaySpacing) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: metrics.weekdayFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(appearance.weekdayText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            LazyVGrid(columns: columns, spacing: metrics.weekdaySpacing) {
                ForEach(days) { day in
                    CalendarDayCellView(
                        day: day,
                        metrics: metrics,
                        appearance: appearance,
                        isSelected: Calendar.autoupdatingCurrent.isDate(day.date, inSameDayAs: selectedDate),
                        isToday: Calendar.autoupdatingCurrent.isDateInToday(day.date),
                        onSelect: onSelectDay
                    )
                }
            }
        }
        .padding(metrics.sectionPadding)
        .background(
            appearance.calendarSurface,
            in: RoundedRectangle(cornerRadius: metrics.sectionCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: metrics.sectionCornerRadius, style: .continuous)
                .stroke(appearance.border, lineWidth: 0.7)
        }
    }
}

private struct CalendarNavButton: View {
    let systemName: String
    let metrics: SchedulePickerMetrics
    let appearance: SchedulePickerAppearance
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: metrics.navIconSize, weight: .bold))
                .foregroundStyle(appearance.navText.opacity(isEnabled ? 1 : 0.35))
                .frame(
                    width: metrics.navButtonSize,
                    height: metrics.navButtonSize
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
    let metrics: SchedulePickerMetrics
    let appearance: SchedulePickerAppearance
    let isSelected: Bool
    let isToday: Bool
    let onSelect: (Date) -> Void

    var body: some View {
        Button(action: { onSelect(day.date) }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: metrics.dayCellCornerRadius, style: .continuous)
                        .fill(appearance.selectedDayFill)
                        .shadow(color: appearance.shadow.opacity(0.3), radius: 3, x: 0, y: 1)
                } else if isToday {
                    RoundedRectangle(cornerRadius: metrics.dayCellCornerRadius, style: .continuous)
                        .stroke(appearance.todayRing, lineWidth: 1)
                }

                Text("\(Calendar.autoupdatingCurrent.component(.day, from: day.date))")
                    .font(.system(size: metrics.dayFontSize, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dayForeground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: metrics.dayCellHeight)
            .contentShape(RoundedRectangle(cornerRadius: metrics.dayCellCornerRadius, style: .continuous))
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
    let metrics: SchedulePickerMetrics
    let appearance: SchedulePickerAppearance
    let onIncrementMinute: () -> Void
    let onDecrementMinute: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: metrics.timeRowSpacing) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(appearance.weekdayText)
                .frame(
                    width: metrics.timeIconSize,
                    height: metrics.timeIconSize
                )

            HStack(spacing: 5) {
                Text(timeText)
                    .font(.system(size: metrics.timeFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(appearance.timeChipText)

                VStack(spacing: 2) {
                    StepperChevronButton(
                        systemName: "chevron.up",
                        metrics: metrics,
                        appearance: appearance,
                        action: onIncrementMinute
                    )

                    StepperChevronButton(
                        systemName: "chevron.down",
                        metrics: metrics,
                        appearance: appearance,
                        action: onDecrementMinute
                    )
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 2)
                .background(
                    appearance.stepperSurface,
                    in: RoundedRectangle(cornerRadius: metrics.stepperCornerRadius, style: .continuous)
                )
            }
            .padding(.horizontal, 8)
            .frame(height: metrics.timeChipHeight)
            .background(
                appearance.timeChipFill,
                in: RoundedRectangle(cornerRadius: metrics.timeChipCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: metrics.timeChipCornerRadius, style: .continuous)
                    .stroke(appearance.border.opacity(0.35), lineWidth: 0.8)
            }

            Spacer(minLength: 0)

            Button(action: onConfirm) {
                Text("确定")
                    .font(.system(size: metrics.confirmFontSize, weight: .semibold))
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
    let metrics: SchedulePickerMetrics
    let appearance: SchedulePickerAppearance
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: metrics.stepperIconSize, weight: .bold))
                .foregroundStyle(appearance.stepperText)
                .frame(
                    width: metrics.stepperButtonWidth,
                    height: metrics.stepperButtonHeight
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
