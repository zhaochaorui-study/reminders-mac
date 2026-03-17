import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReminderStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TodoPanelView(
                    theme: .dark,
                    draftTitle: $store.draftTitle,
                    draftScheduledAt: $store.draftScheduledAt,
                    draftRecurrenceRule: $store.draftRecurrenceRule,
                    items: store.displayedItems,
                    completedCount: store.completedCount,
                    completedHistoryItems: store.completedHistoryItems,
                    highlightedReminderID: store.highlightedReminderID,
                    listScope: store.listScope,
                    isAIParsing: store.isAIParsing,
                    draftValidationMessage: store.draftValidationMessage,
                    onOpenSettings: {},
                    onChangeScope: store.setListScope,
                    onAddReminder: store.addReminder,
                    onAIParse: store.aiParseAndAdd,
                    onDismissDraftValidationMessage: store.clearDraftValidationMessage,
                    onToggleCompletion: store.toggleCompletion,
                    onFocusReminder: store.focusReminder,
                    onSnoozeReminder: store.snoozeReminder,
                    onDeleteReminder: store.deleteReminder,
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
