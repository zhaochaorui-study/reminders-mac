import SwiftUI

struct TodoPanelView: View {
    private enum Layout {
        static let panelSize = CGSize(width: 320, height: 520)
        static let panelCornerRadius: CGFloat = 20
        static let listScopeTopPadding: CGFloat = 3
        static let listScopeBottomPadding: CGFloat = 6
        static let emptyStateVerticalPadding: CGFloat = 10
        static let historyAnimationDuration: Double = 0.18
    }

    let theme: PanelTheme
    @Binding var draftTitle: String
    @Binding var draftScheduledAt: Date
    @Binding var draftRecurrenceRule: RecurrenceRule?
    @Binding var editingTitle: String
    @Binding var editingScheduledAt: Date
    @Binding var editingRecurrenceRule: RecurrenceRule?
    let items: [ReminderItem]
    let completedCount: Int
    let completedHistoryItems: [ReminderItem]
    let highlightedReminderID: ReminderItem.ID?
    let editingReminderID: ReminderItem.ID?
    let listScope: ReminderListScope
    let isAIParsing: Bool
    let draftValidationMessage: String?
    let editingValidationMessage: String?
    let onToggleTheme: () -> Void
    let onChangeScope: (ReminderListScope) -> Void
    let onAddReminder: () -> Void
    let onAIParse: () -> Void
    let onDismissDraftValidationMessage: () -> Void
    let onDismissEditingValidationMessage: () -> Void
    let onToggleCompletion: (ReminderItem) -> Void
    let onEditReminder: (ReminderItem) -> Void
    let onFocusReminder: (ReminderItem) -> Void
    let onSnoozeReminder: (ReminderItem, SnoozeOption) -> Void
    let onDeleteReminder: (ReminderItem) -> Void
    let onCancelEditingReminder: () -> Void
    let onSaveEditingReminder: () -> Void
    let onClearCompleted: () -> Void

    @State private var isShowingCompletedHistory = false

    var body: some View {
        panelContent
            .frame(width: Layout.panelSize.width, height: Layout.panelSize.height)
            .background(RemindersPalette.panel)
            .clipShape(panelShape)
            .overlay {
                panelShape
                    .stroke(RemindersPalette.border.opacity(0.6), lineWidth: 0.5)
            }
            .overlay {
                historyOverlay
            }
            .overlay {
                editingOverlay
            }
            .shadow(color: RemindersPalette.shadow, radius: 20, x: 0, y: 10)
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            PanelHeaderView(theme: theme, onToggleTheme: onToggleTheme)
                .padding(.top, 8)
                .zIndex(3)

            AddReminderBarView(
                theme: theme,
                draftTitle: $draftTitle,
                draftScheduledAt: $draftScheduledAt,
                draftRecurrenceRule: $draftRecurrenceRule,
                isAIParsing: isAIParsing,
                validationMessage: draftValidationMessage,
                onAdd: onAddReminder,
                onAIParse: onAIParse,
                onDismissValidationMessage: onDismissDraftValidationMessage
            )
            .zIndex(2)

            ListScopeSegmentedControlView(
                theme: theme,
                selectedScope: listScope,
                onSelect: onChangeScope
            )
            .zIndex(1)
            .padding(.horizontal, RemindersLayout.panelHorizontalInset)
            .padding(.top, Layout.listScopeTopPadding)
            .padding(.bottom, Layout.listScopeBottomPadding)

            DividerLineView(color: RemindersPalette.border)
                .padding(.horizontal, RemindersLayout.panelHorizontalInset)

            reminderListSection
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            DividerLineView(color: RemindersPalette.border)
                .padding(.horizontal, RemindersLayout.panelHorizontalInset)

            CompletedFooterView(
                theme: theme,
                count: completedCount,
                onShowHistory: showCompletedHistory,
                onClear: onClearCompleted
            )
        }
    }

    @ViewBuilder
    private var reminderListSection: some View {
        if items.isEmpty {
            ReminderEmptyStateView(theme: theme, scope: listScope)
                .padding(.vertical, Layout.emptyStateVerticalPadding)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: RemindersLayout.listRowSpacing) {
                    ForEach(items) { item in
                        reminderRow(for: item)
                    }
                }
                .padding(.horizontal, RemindersLayout.panelHorizontalInset)
                .padding(.vertical, RemindersLayout.listVerticalInset)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private var historyOverlay: some View {
        if isShowingCompletedHistory {
            CompletedHistoryOverlayView(
                theme: theme,
                items: completedHistoryItems,
                onClose: hideCompletedHistory,
                onDelete: onDeleteReminder
            )
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var editingOverlay: some View {
        if editingReminderID != nil {
            ReminderEditorOverlayView(
                theme: theme,
                title: $editingTitle,
                scheduledAt: $editingScheduledAt,
                recurrenceRule: $editingRecurrenceRule,
                validationMessage: editingValidationMessage,
                onCancel: onCancelEditingReminder,
                onSave: onSaveEditingReminder,
                onDismissValidationMessage: onDismissEditingValidationMessage
            )
            .transition(.opacity)
        }
    }

    private var panelShape: some InsettableShape {
        RoundedRectangle(cornerRadius: Layout.panelCornerRadius, style: .continuous)
    }

    private func reminderRow(for item: ReminderItem) -> some View {
        ReminderRowView(
            item: item,
            theme: theme,
            isFocused: highlightedReminderID == item.id,
            onToggleCompletion: { onToggleCompletion(item) },
            onEdit: { onEditReminder(item) },
            onFocus: { onFocusReminder(item) },
            onSnooze: { option in onSnoozeReminder(item, option) },
            onDelete: { onDeleteReminder(item) }
        )
    }

    private func hideCompletedHistory() {
        withAnimation(.easeInOut(duration: Layout.historyAnimationDuration)) {
            isShowingCompletedHistory = false
        }
    }

    private func showCompletedHistory() {
        withAnimation(.easeInOut(duration: Layout.historyAnimationDuration)) {
            isShowingCompletedHistory = true
        }
    }
}
