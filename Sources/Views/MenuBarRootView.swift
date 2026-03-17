import AppKit
import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var store: ReminderStore

    var body: some View {
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
    }
}
