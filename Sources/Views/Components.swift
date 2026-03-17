import SwiftUI

// MARK: - Theme

struct PanelTheme {
    static let dark = PanelTheme()
    static let light = PanelTheme()
}

// MARK: - Header

struct PanelHeaderView: View {
    let theme: PanelTheme
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            Text("待办提醒")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RemindersPalette.primaryText)

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RemindersPalette.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(RemindersPalette.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
}

// MARK: - Segmented Control

struct ListScopeSegmentedControlView: View {
    let theme: PanelTheme
    let selectedScope: ReminderListScope
    let onSelect: (ReminderListScope) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReminderListScope.allCases) { scope in
                Button(action: { onSelect(scope) }) {
                    Text(scope.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(scope == selectedScope ? RemindersPalette.primaryText : RemindersPalette.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            scope == selectedScope
                                ? RemindersPalette.elevated
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
            }
        }
        .padding(4)
        .background(RemindersPalette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    let isAIParsing: Bool
    let validationMessage: String?
    let onAdd: () -> Void
    let onAIParse: () -> Void
    let onDismissValidationMessage: () -> Void

    @State private var isCalendarExpanded = false

    private var canSubmit: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var minimumSelectableDate: Date {
        Self.minimumSelectableDate(from: Date())
    }

    private var scheduleLabel: String {
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

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("", text: $draftTitle, prompt: Text("添加新待办...").foregroundStyle(RemindersPalette.tertiaryText))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(RemindersPalette.primaryText)
                    .onSubmit(onAdd)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(RemindersPalette.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(action: onAIParse) {
                    Group {
                        if isAIParsing {
                            ProgressView()
                                .scaleEffect(0.65)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x7B5EF0), Color(hex: 0x5B8DEF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .opacity(canSubmit && !isAIParsing ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isAIParsing)
                .help("AI 智能解析")

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(RemindersPalette.accentBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .opacity(canSubmit ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCalendarExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RemindersPalette.accentBlue)
                    Text(scheduleLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RemindersPalette.primaryText)
                    Spacer()
                    Image(systemName: isCalendarExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(RemindersPalette.tertiaryText)
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(RemindersPalette.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isCalendarExpanded {
                VStack(spacing: 6) {
                    DatePicker(
                        "",
                        selection: $draftScheduledAt,
                        in: minimumSelectableDate...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(RemindersPalette.accentBlue)
                    .frame(maxHeight: 220)

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RemindersPalette.secondaryText)

                        DatePicker(
                            "",
                            selection: $draftScheduledAt,
                            in: minimumSelectableDate...,
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                        .tint(RemindersPalette.accentBlue)

                        Spacer()

                        Button("确定") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isCalendarExpanded = false
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RemindersPalette.accentBlue)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                }
                .padding(8)
                .background(RemindersPalette.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

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
                .background(Color(hex: 0x341A1A), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(RemindersPalette.accentRed.opacity(0.28), lineWidth: 0.8)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onChange(of: draftTitle) { _, _ in
            guard validationMessage != nil else { return }
            onDismissValidationMessage()
        }
        .onChange(of: draftScheduledAt) { _, _ in
            guard validationMessage != nil else { return }
            onDismissValidationMessage()
        }
    }

    private static func minimumSelectableDate(from date: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let currentMinuteStart = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        return calendar.date(byAdding: .minute, value: 1, to: currentMinuteStart) ?? date.addingTimeInterval(60)
    }
}

// MARK: - Reminder Row

struct ReminderRowView: View {
    let item: ReminderItem
    let theme: PanelTheme
    let isFocused: Bool
    let onToggleCompletion: () -> Void
    let onFocus: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var isExecutionHighlighted: Bool {
        !item.isCompleted && (isFocused || item.tone == .warning)
    }

    private var isHoverActive: Bool {
        !item.isCompleted && isHovered
    }

    private var scheduleColor: Color {
        switch item.tone {
        case .warning: return Color(hex: 0xFF8A78)
        case .completed: return RemindersPalette.tertiaryText
        case .neutral: return RemindersPalette.secondaryText
        }
    }

    private var titleColor: Color {
        if item.isCompleted {
            return RemindersPalette.tertiaryText
        }

        if isExecutionHighlighted {
            return Color(hex: 0xFFF6F1)
        }

        if isHoverActive {
            return Color(hex: 0xFCFCFF)
        }

        return RemindersPalette.primaryText
    }

    private var rowGradientColors: [Color] {
        if isExecutionHighlighted {
            if isHoverActive {
                return [
                    Color(hex: 0x74413B),
                    Color(hex: 0x593735),
                    Color(hex: 0x412C2A)
                ]
            }

            return [
                Color(hex: 0x6A3B36),
                Color(hex: 0x4E322E),
                Color(hex: 0x382725)
            ]
        }

        if isFocused {
            return [RemindersPalette.elevated, RemindersPalette.card]
        }

        if isHoverActive {
            return [Color(hex: 0x36363A), Color(hex: 0x2D2D30)]
        }

        return [RemindersPalette.card, Color(hex: 0x262628)]
    }

    private var rowBorderColor: Color {
        if isExecutionHighlighted {
            return Color(hex: 0xFF8A78, opacity: isHoverActive ? 0.84 : 0.72)
        }

        if isHoverActive {
            return RemindersPalette.accentBlue.opacity(0.58)
        }

        if isFocused {
            return RemindersPalette.accentBlue.opacity(0.42)
        }

        return RemindersPalette.border.opacity(0.42)
    }

    private var rowShadowColor: Color {
        if isExecutionHighlighted {
            return Color(hex: 0xFF5A6E, opacity: isHoverActive ? 0.28 : 0.22)
        }

        if isHoverActive {
            return RemindersPalette.accentBlue.opacity(0.16)
        }

        if isFocused {
            return Color.black.opacity(0.24)
        }

        return Color.black.opacity(0.12)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: isExecutionHighlighted ? 5 : 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(titleColor)
                    .strikethrough(item.isCompleted, color: RemindersPalette.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if isExecutionHighlighted {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFFB38A))
                    }

                    Text(item.scheduleText)
                        .font(.system(size: 11, weight: isExecutionHighlighted ? .semibold : .regular))
                        .foregroundStyle(scheduleColor)
                }
                .padding(.horizontal, isExecutionHighlighted ? 8 : 0)
                .padding(.vertical, isExecutionHighlighted ? 4 : 0)
                .background {
                    if isExecutionHighlighted {
                        Capsule(style: .continuous)
                            .fill(Color(hex: 0x2B1718, opacity: 0.82))
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(Color(hex: 0xFF8A78, opacity: 0.26), lineWidth: 0.8)
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
                Menu {
                    Button(action: onToggleCompletion) {
                        Label(item.isCompleted ? "取消完成" : "标记完成", systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
                    }
                    if !item.isCompleted {
                        Button(action: onFocus) {
                            Label(isFocused ? "收起提醒" : "查看提醒", systemImage: "bell")
                        }
                        Button(action: onSnooze) {
                            Label("稍后 1 小时", systemImage: "clock.badge.plus")
                        }
                    }
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isExecutionHighlighted ? Color(hex: 0xFFD5C8) : RemindersPalette.tertiaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: isExecutionHighlighted ? 58 : 52)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: rowGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(rowBorderColor, lineWidth: isExecutionHighlighted ? 1.1 : 0.75)
                }
                .overlay {
                    if isHoverActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                            .padding(1)
                    }
                }
        }
        .shadow(color: rowShadowColor, radius: isExecutionHighlighted ? (isHoverActive ? 20 : 16) : (isHoverActive ? 14 : 10), x: 0, y: isExecutionHighlighted ? (isHoverActive ? 12 : 10) : (isHoverActive ? 8 : 6))
        .scaleEffect(isHoverActive ? 1.012 : 1)
        .offset(y: isHoverActive ? -1 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 0.5)
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
                .fill(Color.black.opacity(0.18))
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
                                        onSnooze: {},
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
                    .stroke(RemindersPalette.primaryText, lineWidth: 1.5)
                    .background(Circle().fill(Color.clear))
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RemindersPalette.primaryText)
                    }
            } else {
                Text(pendingBadgeText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(style == .alert ? RemindersPalette.accentRed : RemindersPalette.primaryText)
                    .padding(.horizontal, pendingBadgeText.count > 1 ? 2 : 0)
                    .frame(minWidth: 16, minHeight: 16)
            }
        }
        .frame(minWidth: 22, minHeight: 22)
    }
}
