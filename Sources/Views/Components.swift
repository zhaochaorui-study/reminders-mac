import SwiftUI

// MARK: - Theme

struct PanelTheme {
    static let dark = PanelTheme()
    static let light = PanelTheme()
}

// MARK: - Header

struct PanelHeaderView: View {
    private enum Layout {
        static let horizontalSpacing: CGFloat = 8
        static let toggleButtonSize: CGFloat = 30
        static let titleHorizontalPadding: CGFloat = 18
        static let titleVerticalPadding: CGFloat = 1
        static let titleCapsuleHeight: CGFloat = 26
        static let titleOpticalOffsetY: CGFloat = 1
        static let headerHeight: CGFloat = 34
        static let horizontalPadding: CGFloat = 14
    }

    let theme: PanelTheme
    let onToggleTheme: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    private var titleBackgroundColor: Color {
        themeManager.isCandyTheme
            ? RemindersPalette.card
            : RemindersPalette.field
    }

    var body: some View {
        HStack(spacing: Layout.horizontalSpacing) {
            ZStack {
                Capsule(style: .continuous)
                    .fill(titleBackgroundColor)

                Text("待办提醒")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(RemindersPalette.primaryText)
                    .padding(.horizontal, Layout.titleHorizontalPadding)
                    .padding(.vertical, Layout.titleVerticalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: Layout.titleOpticalOffsetY)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: Layout.titleCapsuleHeight)

            Spacer()

            Button(action: onToggleTheme) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(RemindersPalette.card)
                    .overlay {
                        Image(systemName: themeManager.isCandyTheme ? "moon.stars.fill" : "sun.max.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(themeManager.isCandyTheme ? RemindersPalette.accentBlue : RemindersPalette.accentOrange)
                    }
                    .frame(width: Layout.toggleButtonSize, height: Layout.toggleButtonSize)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("切换主题")
        }
        .frame(height: Layout.headerHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.horizontalPadding)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Segmented Control

struct ListScopeSegmentedControlView: View {
    private enum Layout {
        static let controlPadding: CGFloat = 6
        static let itemHeight: CGFloat = 32
        static let selectedCornerRadius: CGFloat = 10
        static let containerCornerRadius: CGFloat = 12
    }

    let theme: PanelTheme
    let selectedScope: ReminderListScope
    let onSelect: (ReminderListScope) -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool { themeManager.isCandyTheme }

    private func candyColor(for scope: ReminderListScope) -> Color {
        scope == .createdToday ? RemindersPalette.accentGreen : RemindersPalette.accentBlue
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ReminderListScope.allCases) { scope in
                Button(action: { onSelect(scope) }) {
                    Text(scope.title)
                        .font(.system(size: 13, weight: .semibold, design: isCandy ? .rounded : .default))
                        .foregroundStyle(
                            isCandy
                                ? (scope == selectedScope ? Color(hex: 0xFBF8F2) : RemindersPalette.primaryText)
                                : (scope == selectedScope ? RemindersPalette.primaryText : RemindersPalette.tertiaryText)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.itemHeight)
                        .background {
                            if isCandy {
                                if scope == selectedScope {
                                    RoundedRectangle(cornerRadius: Layout.selectedCornerRadius, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [candyColor(for: scope), candyColor(for: scope).opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: Layout.selectedCornerRadius, style: .continuous)
                                        .fill(candyColor(for: scope).opacity(0.15))
                                }
                            } else {
                                RoundedRectangle(cornerRadius: Layout.selectedCornerRadius, style: .continuous)
                                    .fill(scope == selectedScope ? RemindersPalette.elevated : Color.clear)
                            }
                        }
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
            }
        }
        .padding(Layout.controlPadding)
        .background(
            RemindersPalette.card,
            in: RoundedRectangle(cornerRadius: Layout.containerCornerRadius, style: .continuous)
        )
        .overlay {
            if isCandy {
                RoundedRectangle(cornerRadius: Layout.containerCornerRadius + 4, style: .continuous)
                    .stroke(RemindersPalette.border.opacity(0.8), lineWidth: 0.8)
            }
        }
    }
}

// MARK: - Empty State

struct ReminderEmptyStateView: View {
    let theme: PanelTheme
    let scope: ReminderListScope

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: scope == .createdToday ? "tray" : "calendar.badge.clock")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(RemindersPalette.tertiaryText)

            Text(scope.emptyTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RemindersPalette.secondaryText)

            Text(scope.emptySubtitle)
                .font(.system(size: 11))
                .foregroundStyle(RemindersPalette.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Add Reminder Bar

struct AddReminderBarView: View {
    let theme: PanelTheme
    @Binding var draftTitle: String
    @Binding var draftScheduledAt: Date
    @Binding var draftRecurrenceRule: RecurrenceRule?
    let isAIParsing: Bool
    let validationMessage: String?
    let onAdd: () -> Void
    let onAIParse: () -> Void
    let onDismissValidationMessage: () -> Void

    private enum Layout {
        static let verticalSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let topPadding: CGFloat = 10
        static let bottomPadding: CGFloat = 4
    }

    @State private var isCalendarExpanded = false
    @State private var cronInput: String = ""
    @ObservedObject private var themeManager = ThemeManager.shared
    private let schedulePickerOffsetY: CGFloat = 46

    private var isCandy: Bool { themeManager.isCandyTheme }

    private var canSubmit: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isCronMode: Bool {
        if case .cron = draftRecurrenceRule { return true }
        return false
    }

    private var isRecurringMode: Bool {
        draftRecurrenceRule != nil
    }

    private var minimumSelectableDate: Date {
        Self.minimumSelectableDate(from: Date())
    }

    private var scheduleLabel: String {
        if let rule = draftRecurrenceRule {
            switch rule {
            case .daily(let hour, let minute):
                return "每天 \(String(format: "%02d:%02d", hour, minute))"
            case .weekly(let weekday, let hour, let minute):
                let name = weekdayShortName(weekday)
                return "每\(name) \(String(format: "%02d:%02d", hour, minute))"
            case .cron:
                return ""
            }
        }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if calendar.isDateInToday(draftScheduledAt) {
            formatter.dateFormat = "今天 HH:mm"
        } else if calendar.isDateInTomorrow(draftScheduledAt) {
            formatter.dateFormat = "明天 HH:mm"
        } else {
            formatter.dateFormat = "M月d日 HH:mm"
        }
        return formatter.string(from: draftScheduledAt)
    }

    private func weekdayShortName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        case 7: return "周六"
        default: return "周?"
        }
    }

    var body: some View {
        VStack(spacing: Layout.verticalSpacing) {
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if draftTitle.isEmpty {
                        Text("添加新待办...")
                            .font(.system(size: 13, weight: .semibold, design: isCandy ? .rounded : .default))
                            .foregroundStyle(RemindersPalette.primaryText.opacity(0.56))
                            .padding(.horizontal, 12)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold, design: isCandy ? .rounded : .default))
                        .foregroundStyle(RemindersPalette.primaryText)
                        .onSubmit(onAdd)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .background(
                    isCandy ? RemindersPalette.candyFieldBlue : RemindersPalette.field,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    if isCandy {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(RemindersPalette.accentBlue.opacity(0.32), lineWidth: 1)
                    }
                }
                .shadow(color: RemindersPalette.shadow.opacity(isCandy ? 0.18 : 0.06), radius: 8, x: 0, y: 2)

                Button(action: onAIParse) {
                    Group {
                        if isAIParsing {
                            ProgressView()
                                .tint(RemindersPalette.primaryText)
                                .scaleEffect(0.65)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(RemindersPalette.primaryText)
                    .frame(width: 42, height: 42)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: isCandy
                                        ? [RemindersPalette.accentBlue, Color(hex: 0x4B6F95)]
                                        : [Color(hex: 0x7B5EF0), Color(hex: 0x5B8DEF)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(canSubmit && !isAIParsing ? 1 : 0.62)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isAIParsing)
                .help("AI 智能解析")

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(RemindersPalette.primaryText)
                        .frame(width: 42, height: 42)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    isCandy
                                        ? AnyShapeStyle(LinearGradient(colors: [RemindersPalette.accentGreen, Color(hex: 0x4E725F)], startPoint: .top, endPoint: .bottom))
                                        : AnyShapeStyle(RemindersPalette.accentBlue)
                                )
                                .opacity(canSubmit ? 1 : 0.62)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }

            if !isCronMode {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCalendarExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RemindersPalette.accentBlue)
                        Text(scheduleLabel)
                            .font(.system(size: 12, weight: .semibold, design: isCandy ? .rounded : .default))
                            .foregroundStyle(RemindersPalette.primaryText)
                        Spacer()
                        Image(systemName: isCalendarExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(isCandy ? RemindersPalette.accentOrange : RemindersPalette.tertiaryText)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        isCandy ? RemindersPalette.candyCardYellow : RemindersPalette.field,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        if isCandy {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(RemindersPalette.accentBlue.opacity(0.18), lineWidth: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topLeading) {
                    if isCalendarExpanded {
                        ScheduleDateTimePickerView(
                            selection: $draftScheduledAt,
                            minimumDate: minimumSelectableDate,
                            isRecurringMode: isRecurringMode,
                            onConfirm: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isCalendarExpanded = false
                                }
                            }
                        )
                        .offset(y: schedulePickerOffsetY)
                        .transition(.opacity)
                        .zIndex(20)
                    }
                }
                .zIndex(isCalendarExpanded ? 20 : 0)
            }

            RecurrenceRulePicker(
                rule: $draftRecurrenceRule,
                scheduledAt: draftScheduledAt,
                cronInput: $cronInput
            )
            .allowsHitTesting(!isCalendarExpanded)
            .opacity(isCalendarExpanded ? 0.3 : 1)

            if let validationMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))

                    Text(validationMessage)
                        .font(.system(size: 11, weight: .medium))

                    Spacer(minLength: 0)
                }
                .foregroundStyle(RemindersPalette.accentRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RemindersPalette.validationBg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(RemindersPalette.accentRed.opacity(0.28), lineWidth: 0.8)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.topPadding)
        .padding(.bottom, Layout.bottomPadding)
        .onChange(of: draftTitle) { _, _ in
            guard validationMessage != nil else { return }
            onDismissValidationMessage()
        }
        .onChange(of: draftScheduledAt) { _, newValue in
            if validationMessage != nil {
                onDismissValidationMessage()
            }
            syncRecurrenceTime(from: newValue)
        }
    }

    private func syncRecurrenceTime(from date: Date) {
        guard let rule = draftRecurrenceRule else { return }
        let calendar = Calendar.autoupdatingCurrent
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 9
        let minute = comps.minute ?? 0

        switch rule {
        case .daily:
            draftRecurrenceRule = .daily(hour: hour, minute: minute)
        case .weekly(let weekday, _, _):
            draftRecurrenceRule = .weekly(weekday: weekday, hour: hour, minute: minute)
        case .cron:
            break
        }
    }

    private static func minimumSelectableDate(from date: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let currentMinuteStart = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        return calendar.date(byAdding: .minute, value: 1, to: currentMinuteStart) ?? date.addingTimeInterval(60)
    }
}

// MARK: - Recurrence Rule Picker

private enum RecurrencePickerMode: String, CaseIterable {
    case none
    case daily
    case weekly
    case cron

    var label: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .cron: return "Cron"
        }
    }
}

struct RecurrenceRulePicker: View {
    private enum Layout {
        static let modeHeight: CGFloat = 30
        static let modeHorizontalPadding: CGFloat = 12
    }

    @Binding var rule: RecurrenceRule?
    let scheduledAt: Date
    @Binding var cronInput: String
    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool { themeManager.isCandyTheme }

    private var pickerMode: RecurrencePickerMode {
        guard let rule else { return .none }
        switch rule {
        case .daily: return .daily
        case .weekly: return .weekly
        case .cron: return .cron
        }
    }

    private func candyPillColor(for mode: RecurrencePickerMode) -> Color {
        switch mode {
        case .none: return RemindersPalette.accentOrange
        case .daily: return RemindersPalette.accentGreen
        case .weekly: return RemindersPalette.accentBlue
        case .cron: return RemindersPalette.accentPurple
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                ForEach(RecurrencePickerMode.allCases, id: \.rawValue) { mode in
                    modeButton(for: mode)

                    Spacer(minLength: 0)
                }
            }
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RemindersPalette.card)
                    .overlay {
                        if isCandy {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(RemindersPalette.border, lineWidth: 0.8)
                        }
                    }
            }

            if pickerMode == .cron {
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(RemindersPalette.secondaryText)

                    TextField("", text: $cronInput, prompt: Text("分 时 日 月 周").foregroundStyle(RemindersPalette.tertiaryText))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(RemindersPalette.primaryText)
                        .onSubmit { applyCron() }
                        .onChange(of: cronInput) { _, _ in applyCron() }

                    if case .cron = rule {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(RemindersPalette.accentGreen)
                    } else if !cronInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(RemindersPalette.accentRed)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(RemindersPalette.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func modeButton(for mode: RecurrencePickerMode) -> some View {
        Button(action: { selectMode(mode) }) {
            Text(mode.label)
                .font(.system(size: 12, weight: .semibold, design: isCandy ? .rounded : .default))
                .foregroundStyle(
                    isCandy
                        ? (pickerMode == mode ? Color(hex: 0xFBF8F2) : RemindersPalette.primaryText)
                        : (pickerMode == mode ? RemindersPalette.primaryText : RemindersPalette.tertiaryText)
                )
                .padding(.horizontal, Layout.modeHorizontalPadding)
                .frame(height: Layout.modeHeight)
                .background {
                    if isCandy {
                        Capsule(style: .continuous)
                            .fill(
                                pickerMode == mode
                                    ? candyPillColor(for: mode)
                                    : candyPillColor(for: mode).opacity(0.2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(pickerMode == mode ? RemindersPalette.elevated : Color.clear)
                    }
                }
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
    }

    private func selectMode(_ mode: RecurrencePickerMode) {
        let calendar = Calendar.autoupdatingCurrent
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: scheduledAt)
        let hour = comps.hour ?? 9
        let minute = comps.minute ?? 0
        let weekday = comps.weekday ?? 2

        switch mode {
        case .none:
            rule = nil
            cronInput = ""
        case .daily:
            rule = .daily(hour: hour, minute: minute)
        case .weekly:
            rule = .weekly(weekday: weekday, hour: hour, minute: minute)
        case .cron:
            if cronInput.isEmpty {
                cronInput = "\(minute) \(hour) * * *"
            }
            applyCron()
        }
    }

    private func applyCron() {
        let trimmed = cronInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rule = nil
            return
        }
        if CronExpression.parse(trimmed) != nil {
            rule = .cron(trimmed)
        }
    }
}

// MARK: - Reminder Row

private struct ReminderRecurrenceBadge: View {
    private enum Layout {
        static let iconSize: CGFloat = 9
        static let iconFrameWidth: CGFloat = 10
    }

    let label: String
    let style: ReminderMetadataBadgeStyle
    let font: Font

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: Layout.iconSize, weight: .semibold))
                .frame(width: Layout.iconFrameWidth, height: Layout.iconFrameWidth)

            Text(label)
                .font(font)
                .lineLimit(1)
        }
        .foregroundStyle(style.foreground)
        .padding(.leading, RemindersLayout.reminderRowMetadataBadgeHorizontalInset)
        .padding(.trailing, RemindersLayout.reminderRowMetadataBadgeTrailingInset)
        .padding(.vertical, RemindersLayout.reminderRowMetadataBadgeVerticalInset)
        .background(style.background, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(style.border, lineWidth: 0.8)
        }
        .frame(minHeight: RemindersLayout.reminderRowMetadataHeight)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct ReminderRowView: View {
    let item: ReminderItem
    let theme: PanelTheme
    let isFocused: Bool
    let onToggleCompletion: () -> Void
    let onFocus: () -> Void
    let onSnooze: (SnoozeOption) -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isShowingActionMenu = false
    @ObservedObject private var themeManager = ThemeManager.shared

    private var isCandy: Bool { themeManager.isCandyTheme }

    private var isExecutionHighlighted: Bool {
        !item.isCompleted && (isFocused || item.tone == .warning)
    }

    private var isHoverActive: Bool {
        !item.isCompleted && isHovered
    }

    private var scheduleSummaryText: String {
        item.scheduleSummaryText
    }

    private var scheduleColor: Color {
        switch item.tone {
        case .warning: return isCandy ? RemindersPalette.accentOrange : Color(hex: 0xFF8A78)
        case .completed: return RemindersPalette.tertiaryText
        case .neutral: return RemindersPalette.secondaryText
        }
    }

    private var titleColor: Color {
        if item.isCompleted { return RemindersPalette.tertiaryText }
        if isExecutionHighlighted { return isCandy ? Color(hex: 0x55473F) : Color(hex: 0xFFF6F1) }
        if isHoverActive { return isCandy ? Color(hex: 0x4A3D37) : Color(hex: 0xFCFCFF) }
        return RemindersPalette.primaryText
    }

    private var rowGradientColors: [Color] {
        if isCandy {
            if isExecutionHighlighted {
                return isHoverActive
                    ? [Color(hex: 0xFAEEDD), Color(hex: 0xF5E2CC)]
                    : [Color(hex: 0xF9F0E2), Color(hex: 0xF4E7D6)]
            }
            if isFocused { return [Color(hex: 0xEEF5EE), Color(hex: 0xE7F0E8)] }
            if isHoverActive { return [Color(hex: 0xF6F1E7), Color(hex: 0xF1EBDF)] }
            return [Color(hex: 0xF5EFE5), Color(hex: 0xF0E9DE)]
        } else {
            if isExecutionHighlighted {
                return isHoverActive
                    ? [Color(hex: 0x74413B), Color(hex: 0x593735), Color(hex: 0x412C2A)]
                    : [Color(hex: 0x6A3B36), Color(hex: 0x4E322E), Color(hex: 0x382725)]
            }
            if isFocused { return [RemindersPalette.elevated, RemindersPalette.card] }
            if isHoverActive { return [Color(hex: 0x36363A), Color(hex: 0x2D2D30)] }
            return [RemindersPalette.card, Color(hex: 0x262628)]
        }
    }

    private var rowBorderColor: Color {
        if isExecutionHighlighted {
            return isCandy
                ? Color(hex: 0xB27744, opacity: isHoverActive ? 0.58 : 0.42)
                : Color(hex: 0xFF8A78, opacity: isHoverActive ? 0.84 : 0.72)
        }
        if isHoverActive { return RemindersPalette.accentBlue.opacity(isCandy ? 0.28 : 0.58) }
        if isFocused { return RemindersPalette.accentBlue.opacity(isCandy ? 0.22 : 0.42) }
        return isCandy ? Color(hex: 0xD8D1C4, opacity: 0.8) : RemindersPalette.border.opacity(0.42)
    }

    private var rowShadowColor: Color {
        if isCandy {
            if isExecutionHighlighted { return Color(hex: 0xB27744, opacity: isHoverActive ? 0.16 : 0.11) }
            if isHoverActive { return RemindersPalette.accentBlue.opacity(0.08) }
            return Color(hex: 0x927B61, opacity: 0.08)
        } else {
            if isExecutionHighlighted { return Color(hex: 0xFF5A6E, opacity: isHoverActive ? 0.28 : 0.22) }
            if isHoverActive { return RemindersPalette.accentBlue.opacity(0.16) }
            if isFocused { return Color.black.opacity(0.24) }
            return Color.black.opacity(0.12)
        }
    }

    private var menuButtonGradientColors: [Color] {
        if isExecutionHighlighted {
            return isCandy
                ? [Color(hex: 0x3A3D43), Color(hex: 0x1C1F24)]
                : [Color(hex: 0x7E4038), Color(hex: 0x582E2B)]
        }
        if isCandy {
            return isHoverActive
                ? [Color(hex: 0x43474E), Color(hex: 0x23272D)]
                : [Color(hex: 0x363A40), Color(hex: 0x171A1F)]
        }
        return isHoverActive
            ? [Color(hex: 0x4A4A52), Color(hex: 0x303037)]
            : [Color(hex: 0x414149), Color(hex: 0x2B2B31)]
    }

    private var menuButtonBorderColor: Color {
        if isExecutionHighlighted {
            return isCandy ? Color.white.opacity(0.18) : Color(hex: 0xFF8A78, opacity: 0.32)
        }
        if isCandy {
            return Color.white.opacity(0.14)
        }
        return Color.white.opacity(0.14)
    }

    private var menuButtonIconColor: Color {
        if isExecutionHighlighted {
            return isCandy ? .black : Color(hex: 0xFFE5DE)
        }
        if isCandy {
            return .black
        }
        return RemindersPalette.secondaryText
    }

    private var menuButtonShadowColor: Color {
        if isExecutionHighlighted {
            return isCandy ? Color.black.opacity(0.22) : Color(hex: 0xFF8A78, opacity: 0.18)
        }
        if isCandy {
            return Color.black.opacity(isHoverActive ? 0.24 : 0.18)
        }
        return Color.black.opacity(0.14)
    }

    private var menuButtonHighlightColor: Color {
        if isExecutionHighlighted {
            return Color.white.opacity(isCandy ? 0.24 : 0.08)
        }
        if isCandy {
            return Color.white.opacity(isHoverActive ? 0.32 : 0.24)
        }
        return Color.white.opacity(0.08)
    }

    private var actionMenuBackgroundColor: Color {
        isCandy ? Color(hex: 0xFBF5EA) : RemindersPalette.panel
    }

    private var actionMenuBorderColor: Color {
        isCandy ? Color(hex: 0xDCCCB5, opacity: 0.92) : RemindersPalette.border.opacity(0.9)
    }

    private var actionMenuShadowColor: Color {
        isCandy ? Color(hex: 0x8F765B, opacity: 0.16) : Color.black.opacity(0.28)
    }

    private var actionMenuMutedTextColor: Color {
        isCandy ? Color(hex: 0x8A745C) : RemindersPalette.secondaryText
    }

    private var reminderTitleFont: Font {
        .system(size: 13, weight: .semibold, design: .default)
    }

    private var reminderMetadataFont: Font {
        .system(size: 11, weight: isExecutionHighlighted ? .semibold : .regular, design: .default)
    }

    private var reminderBadgeFont: Font {
        .system(size: 11, weight: isExecutionHighlighted ? .semibold : .medium, design: .default)
    }

    @ViewBuilder
    private var metadataLine: some View {
        HStack(spacing: 6) {
            if isExecutionHighlighted {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isCandy ? RemindersPalette.accentOrange : Color(hex: 0xFFB38A))
            }

            Text(scheduleSummaryText)
                .font(reminderMetadataFont)
                .foregroundStyle(scheduleColor)
                .lineLimit(1)

            if let rule = item.recurrenceRule {
                ReminderRecurrenceBadge(
                    label: rule.shortLabel,
                    style: RemindersPalette.recurrenceBadgeStyle(for: rule, isCompleted: item.isCompleted),
                    font: reminderBadgeFont
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: RemindersLayout.reminderRowMetadataHeight, alignment: .leading)
    }

    @ViewBuilder
    private var menuTriggerLabel: some View {
        if isCandy {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFFF9F1), Color(hex: 0xEEDBC4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .stroke(Color(hex: 0xD6B28A, opacity: 0.95), lineWidth: 0.85)
                    }
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .stroke(Color.white.opacity(0.72), lineWidth: 0.7)
                            .padding(1.1)
                    }

                Circle()
                    .fill(Color(hex: 0x9D7A55, opacity: 0.08))
                    .frame(width: 15, height: 15)
                    .blur(radius: 0.3)
                    .offset(x: 0.4, y: 0.8)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.62))
                    .frame(width: 8, height: 3)
                    .blur(radius: 0.35)
                    .offset(x: -2.8, y: -4.8)

                HStack(spacing: 3.2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color(hex: 0x23262A))
                            .frame(width: 2.6, height: 2.6)
                    }
                }
            }
            .frame(width: 23, height: 23)
            .shadow(color: Color(hex: 0x927553, opacity: isHoverActive ? 0.16 : 0.1), radius: isHoverActive ? 8 : 5, x: 0, y: isHoverActive ? 4 : 2)
            .scaleEffect(isHoverActive ? 1.03 : 1)
            .contentShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: menuButtonGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .stroke(menuButtonBorderColor, lineWidth: 0.9)
                    }
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .stroke(menuButtonHighlightColor, lineWidth: 0.8)
                            .padding(1.1)
                    }

                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 15, height: 15)
                    .blur(radius: 0.2)
                    .offset(x: -0.5, y: -0.5)

                Capsule(style: .continuous)
                    .fill(menuButtonHighlightColor)
                    .frame(width: 8, height: 3)
                    .blur(radius: 0.35)
                    .offset(x: -2.8, y: -4.8)

                HStack(spacing: 2.5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(menuButtonIconColor)
                            .frame(width: 2.6, height: 2.6)
                    }
                }
            }
            .frame(width: 23, height: 23)
            .shadow(color: menuButtonShadowColor, radius: isHoverActive ? 8 : 5, x: 0, y: isHoverActive ? 4 : 2)
            .scaleEffect(isHoverActive ? 1.03 : 1)
            .contentShape(Circle())
        }
    }

    @ViewBuilder
    private var actionMenuPopover: some View {
        VStack(alignment: .leading, spacing: 7) {
            actionMenuButton(
                title: item.isCompleted ? "取消完成" : "标记完成",
                systemName: item.isCompleted ? "arrow.uturn.backward" : "checkmark",
                action: {
                    isShowingActionMenu = false
                    onToggleCompletion()
                }
            )

            if !item.isCompleted {
                actionMenuButton(
                    title: isFocused ? "收起提醒" : "查看提醒",
                    systemName: "bell",
                    action: {
                        isShowingActionMenu = false
                        onFocus()
                    }
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("稍后提醒")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(actionMenuMutedTextColor)

                    HStack(spacing: 5) {
                        ForEach(SnoozeOption.allCases) { option in
                            Button(option.title) {
                                isShowingActionMenu = false
                                onSnooze(option)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isCandy ? Color(hex: 0x4F3F35) : RemindersPalette.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                isCandy ? Color(hex: 0xF1E4D2) : RemindersPalette.card,
                                in: Capsule(style: .continuous)
                            )
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(
                                        isCandy ? Color(hex: 0xD6C0A2, opacity: 0.85) : RemindersPalette.border.opacity(0.72),
                                        lineWidth: 0.8
                                    )
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }

            DividerLineView(color: actionMenuBorderColor.opacity(0.7))

            actionMenuButton(
                title: "删除",
                systemName: "trash",
                role: .destructive,
                action: {
                    isShowingActionMenu = false
                    onDelete()
                }
            )
        }
        .padding(8)
        .frame(width: 160, alignment: .leading)
        .background(
            actionMenuBackgroundColor,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(actionMenuBorderColor, lineWidth: 0.9)
        }
        .shadow(color: actionMenuShadowColor, radius: 16, x: 0, y: 10)
    }

    private func actionMenuButton(
        title: String,
        systemName: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 13)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))

                Spacer(minLength: 0)
            }
            .foregroundStyle(role == .destructive ? RemindersPalette.accentRed : RemindersPalette.primaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (role == .destructive
                    ? RemindersPalette.validationBg.opacity(isCandy ? 0.72 : 0.48)
                    : (isCandy ? Color(hex: 0xF7ECDD, opacity: 0.76) : RemindersPalette.card.opacity(0.76))),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: isExecutionHighlighted ? 5 : 3) {
                Text(item.title)
                    .font(reminderTitleFont)
                    .foregroundStyle(titleColor)
                    .strikethrough(item.isCompleted, color: RemindersPalette.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: RemindersLayout.reminderRowTitleHeight, alignment: .leading)

                metadataLine
                .padding(.horizontal, isExecutionHighlighted ? 8 : 0)
                .padding(.vertical, isExecutionHighlighted ? 4 : 0)
                .background {
                    if isExecutionHighlighted {
                        Capsule(style: .continuous)
                            .fill(isCandy ? Color(hex: 0xF5E8D9, opacity: 0.9) : Color(hex: 0x2B1718, opacity: 0.82))
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(isCandy ? RemindersPalette.accentOrange.opacity(0.28) : Color(hex: 0xFF8A78, opacity: 0.26), lineWidth: 0.8)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

            if item.isCompleted {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RemindersPalette.tertiaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    isShowingActionMenu.toggle()
                }) {
                    menuTriggerLabel
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isShowingActionMenu, arrowEdge: .bottom) {
                    actionMenuPopover
                }
                .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: isExecutionHighlighted ? 58 : 52)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: rowGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(rowBorderColor, lineWidth: isExecutionHighlighted ? 1.1 : 0.75)
                }
                .overlay {
                    if isHoverActive {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isCandy ? Color(hex: 0xDCC9B8, opacity: 0.35) : Color.white.opacity(0.05), lineWidth: 0.8)
                            .padding(1)
                    }
                }
        }
        .shadow(color: rowShadowColor, radius: isExecutionHighlighted ? (isHoverActive ? 20 : 16) : (isHoverActive ? 14 : 10), x: 0, y: isExecutionHighlighted ? (isHoverActive ? 12 : 10) : (isHoverActive ? 8 : 6))
        .scaleEffect(isHoverActive ? 1.012 : 1)
        .offset(y: isHoverActive ? -1 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onHover { hovering in
            isHovered = !item.isCompleted && hovering
        }
        .animation(.easeOut(duration: 0.18), value: isExecutionHighlighted)
        .animation(.easeOut(duration: 0.18), value: isHoverActive)
    }
}

// MARK: - Divider

struct DividerLineView: View {
    let color: Color
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        if themeManager.isCandyTheme {
            Line()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(RemindersPalette.dividerDash)
                .frame(height: 1)
        } else {
            Rectangle()
                .fill(color)
                .frame(height: 0.5)
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

// MARK: - Completed Footer

struct CompletedFooterView: View {
    let theme: PanelTheme
    let count: Int
    let onShowHistory: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            Button(action: onShowHistory) {
                HStack(spacing: 4) {
                    Text("已完成 (\(count))")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(RemindersPalette.secondaryText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RemindersPalette.accentBlue)
                    .frame(width: 28, height: 28)
                    .opacity(count > 0 ? 1 : 0.35)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}

struct CompletedHistoryOverlayView: View {
    let theme: PanelTheme
    let items: [ReminderItem]
    let onClose: () -> Void
    let onDelete: (ReminderItem) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(RemindersPalette.overlayDim)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("历史完成")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RemindersPalette.primaryText)
                        Text("显示昨天及更早的已完成事项")
                            .font(.system(size: 11))
                            .foregroundStyle(RemindersPalette.tertiaryText)
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RemindersPalette.secondaryText)
                            .frame(width: 28, height: 28)
                            .background(RemindersPalette.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                DividerLineView(color: RemindersPalette.border)
                    .padding(.horizontal, RemindersLayout.panelHorizontalInset)

                Group {
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(RemindersPalette.tertiaryText)

                            Text("昨天及更早暂无历史")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RemindersPalette.secondaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: RemindersLayout.listRowSpacing) {
                                ForEach(items) { item in
                                    ReminderRowView(
                                        item: item,
                                        theme: theme,
                                        isFocused: false,
                                        onToggleCompletion: {},
                                        onFocus: {},
                                        onSnooze: { _ in },
                                        onDelete: { onDelete(item) }
                                    )
                                }
                            }
                            .padding(.horizontal, RemindersLayout.panelHorizontalInset)
                            .padding(.vertical, RemindersLayout.listVerticalInset)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: 304, height: 360)
            .background(RemindersPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(RemindersPalette.border.opacity(0.7), lineWidth: 0.5)
            }
            .padding(8)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Popup Action Button

struct SnoozeOptionMenuButtonView: View {
    let title: String
    let background: Color
    let foreground: Color
    let onSelect: (SnoozeOption) -> Void

    var body: some View {
        Menu {
            ForEach(SnoozeOption.allCases) { option in
                Button(option.title) {
                    onSelect(option)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PopupActionButtonView: View {
    let title: String
    let background: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 36)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu Bar Status Glyph

struct MenuStatusGlyphView: View {
    enum Style {
        case normal
        case pending
        case alert
    }

    let style: Style
    let badgeCount: Int

    private var pendingBadgeText: String {
        badgeCount > 99 ? "99+" : "\(max(badgeCount, 1))"
    }

    var body: some View {
        Group {
            if style == .normal {
                Circle()
                    .fill(RemindersPalette.menuBarBadgeBackground)
                    .overlay {
                        Circle()
                            .stroke(RemindersPalette.menuBarBadgeBorder, lineWidth: 0.8)
                    }
                    .frame(width: 18, height: 18)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(RemindersPalette.menuBarBadgeText)
                    }
            } else {
                Text(pendingBadgeText)
                    .font(.system(size: pendingBadgeText.count > 1 ? 11 : 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(style == .alert ? RemindersPalette.accentRed : RemindersPalette.menuBarBadgeText)
                    .padding(.horizontal, pendingBadgeText.count > 1 ? 5 : 4)
                    .padding(.vertical, 2)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(RemindersPalette.menuBarBadgeBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(RemindersPalette.menuBarBadgeBorder, lineWidth: 0.8)
                            }
                    }
                    .shadow(color: RemindersPalette.shadow.opacity(0.16), radius: 1, x: 0, y: 0.5)
            }
        }
        .frame(minWidth: 22, minHeight: 22)
    }
}
