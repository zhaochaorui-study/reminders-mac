import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReminderStore
    @ObservedObject private var themeManager = ThemeManager.shared

    private var activeTheme: PanelTheme {
        themeManager.isCandyTheme ? .light : .dark
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TodoPanelView(
                    theme: activeTheme,
                    draftTitle: $store.draftTitle,
                    draftScheduledAt: $store.draftScheduledAt,
                    draftRecurrenceRule: $store.draftRecurrenceRule,
                    editingTitle: $store.editingTitle,
                    editingScheduledAt: $store.editingScheduledAt,
                    editingRecurrenceRule: $store.editingRecurrenceRule,
                    items: store.displayedItems,
                    completedCount: store.completedCount,
                    completedHistoryItems: store.completedHistoryItems,
                    highlightedReminderID: store.highlightedReminderID,
                    editingReminderID: store.editingReminderID,
                    listScope: store.listScope,
                    isAIParsing: store.isAIParsing,
                    draftValidationMessage: store.draftValidationMessage,
                    editingValidationMessage: store.editingValidationMessage,
                    onToggleTheme: { themeManager.toggle() },
                    onChangeScope: store.setListScope,
                    onAddReminder: store.addReminder,
                    onAIParse: store.aiParseAndAdd,
                    onDismissDraftValidationMessage: store.clearDraftValidationMessage,
                    onDismissEditingValidationMessage: store.clearEditingValidationMessage,
                    onToggleCompletion: store.toggleCompletion,
                    onEditReminder: store.startEditing,
                    onFocusReminder: store.focusReminder,
                    onSnoozeReminder: { item, option in store.snoozeReminder(item, after: option) },
                    onDeleteReminder: store.deleteReminder,
                    onCancelEditingReminder: store.cancelEditing,
                    onSaveEditingReminder: store.saveEditingReminder,
                    onClearCompleted: store.clearCompleted
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("菜单栏状态预览")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RemindersPalette.primaryText)

                    MenuBarStatusStatesView(
                        pendingCount: store.pendingCount,
                        hasHighlightedReminder: store.highlightedReminder != nil
                    )
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(RemindersPalette.card)
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(RemindersPalette.canvas)
        .frame(minWidth: 420, minHeight: 700)
    }
}
