import AppKit
import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var store: ReminderStore
    @ObservedObject private var themeManager = ThemeManager.shared

    private var activeTheme: PanelTheme {
        themeManager.isCandyTheme ? .light : .dark
    }

    var body: some View {
        TodoPanelView(
            theme: activeTheme,
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
            onToggleTheme: { themeManager.toggle() },
            onChangeScope: store.setListScope,
            onAddReminder: store.addReminder,
            onAIParse: store.aiParseAndAdd,
            onDismissDraftValidationMessage: store.clearDraftValidationMessage,
            onToggleCompletion: store.toggleCompletion,
            onFocusReminder: store.focusReminder,
            onSnoozeReminder: { item, option in store.snoozeReminder(item, after: option) },
            onDeleteReminder: store.deleteReminder,
            onClearCompleted: store.clearCompleted
        )
    }
}
