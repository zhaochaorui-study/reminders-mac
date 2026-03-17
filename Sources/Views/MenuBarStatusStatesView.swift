import SwiftUI

struct MenuBarStatusStatesView: View {
    let pendingCount: Int
    let hasHighlightedReminder: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            statusItem(title: "常态", style: .normal)
            statusItem(title: "有待办", style: .pending)
            statusItem(title: "提醒中", style: .alert)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 300, height: 80, alignment: .leading)
    }

    private func statusItem(title: String, style: MenuStatusGlyphView.Style) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(RemindersPalette.lightSecondaryText)
            MenuStatusGlyphView(style: resolvedStyle(for: style), badgeCount: pendingCount)
        }
    }

    private func resolvedStyle(for style: MenuStatusGlyphView.Style) -> MenuStatusGlyphView.Style {
        switch style {
        case .normal:
            return pendingCount == 0 && !hasHighlightedReminder ? .normal : .normal
        case .pending:
            return pendingCount > 0 ? .pending : .normal
        case .alert:
            return hasHighlightedReminder ? .alert : .normal
        }
    }
}
