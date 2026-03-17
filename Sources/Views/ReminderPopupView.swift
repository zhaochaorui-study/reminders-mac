import SwiftUI

struct ReminderPopupView: View {
    let reminder: ReminderItem
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RemindersPalette.accentOrange)
                    Text("提醒")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RemindersPalette.primaryText)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RemindersPalette.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(RemindersPalette.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RemindersPalette.primaryText)
                    .lineLimit(2)

                Text("预定时间：\(reminder.scheduleText)")
                    .font(.system(size: 12))
                    .foregroundStyle(RemindersPalette.accentRed)

                HStack(spacing: 8) {
                    PopupActionButtonView(
                        title: "稍后提醒",
                        background: RemindersPalette.elevated,
                        foreground: RemindersPalette.primaryText,
                        action: onSnooze
                    )

                    PopupActionButtonView(
                        title: "标记完成",
                        background: RemindersPalette.accentBlue,
                        foreground: .white,
                        action: onComplete
                    )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 280)
        .background(RemindersPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RemindersPalette.border.opacity(0.5), lineWidth: 0.5)
        }
        .shadow(color: RemindersPalette.shadow, radius: 16, x: 0, y: 8)
    }
}
