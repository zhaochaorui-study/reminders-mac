import SwiftUI

struct TodoPanelView: View {
    let theme: PanelTheme
    @Binding var draftTitle: String
    @Binding var draftScheduledAt: Date
    let items: [ReminderItem]
    let completedCount: Int
    let completedHistoryItems: [ReminderItem]
    let highlightedReminderID: ReminderItem.ID?
    let listScope: ReminderListScope
    let isAIParsing: Bool
    let draftValidationMessage: String?
    let onOpenSettings: () -> Void
    let onChangeScope: (ReminderListScope) -> Void
    let onAddReminder: () -> Void
    let onAIParse: () -> Void
    let onDismissDraftValidationMessage: () -> Void
    let onToggleCompletion: (ReminderItem) -> Void
    let onFocusReminder: (ReminderItem) -> Void
    let onSnoozeReminder: (ReminderItem) -> Void
    let onDeleteReminder: (ReminderItem) -> Void
    let onClearCompleted: () -> Void

    @State private var isShowingCompletedHistory = false

    var body: some View {
        VStack(spacing: 0) {
            PanelHeaderView(theme: theme, onOpenSettings: onOpenSettings)

            AddReminderBarView(
                theme: theme,
                draftTitle: $draftTitle,
                draftScheduledAt: $draftScheduledAt,
                isAIParsing: isAIParsing,
                validationMessage: draftValidationMessage,
                onAdd: onAddReminder,
                onAIParse: onAIParse,
                onDismissValidationMessage: onDismissDraftValidationMessage
            )

            ListScopeSegmentedControlView(
                theme: theme,
                selectedScope: listScope,
                onSelect: onChangeScope
            )
            .padding(.horizontal, RemindersLayout.panelHorizontalInset)
            .padding(.vertical, 6)

            DividerLineView(color: RemindersPalette.border)
                .padding(.horizontal, RemindersLayout.panelHorizontalInset)

            Group {
                if items.isEmpty {
                    ReminderEmptyStateView(theme: theme, scope: listScope)
                        .padding(.vertical, 10)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: RemindersLayout.listRowSpacing) {
                            ForEach(items) { item in
                                ReminderRowView(
                                    item: item,
                                    theme: theme,
                                    isFocused: highlightedReminderID == item.id,
                                    onToggleCompletion: { onToggleCompletion(item) },
                                    onFocus: { onFocusReminder(item) },
                                    onSnooze: { onSnoozeReminder(item) },
                                    onDelete: { onDeleteReminder(item) }
                                )
                            }
                        }
                        .padding(.horizontal, RemindersLayout.panelHorizontalInset)
                        .padding(.vertical, RemindersLayout.listVerticalInset)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            DividerLineView(color: RemindersPalette.border)
                .padding(.horizontal, RemindersLayout.panelHorizontalInset)

            CompletedFooterView(
                theme: theme,
                count: completedCount,
                onShowHistory: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isShowingCompletedHistory = true
                    }
                },
                onClear: onClearCompleted
            )
        }
        .frame(width: 320, height: 520)
        .background(RemindersPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RemindersPalette.border.opacity(0.6), lineWidth: 0.5)
        }
        .overlay {
            if isShowingCompletedHistory {
                CompletedHistoryOverlayView(
                    theme: theme,
                    items: completedHistoryItems,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isShowingCompletedHistory = false
                        }
                    },
                    onDelete: onDeleteReminder
                )
                .transition(.opacity)
            }
        }
        .shadow(color: RemindersPalette.shadow, radius: 20, x: 0, y: 10)
    }
}
