import SwiftUI

struct ContextPreviewView: View {
    let reminder: ReminderItem
    let pendingCount: Int
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    let onComplete: () -> Void

    private var statusTitle: String {
        reminder.scheduleText
    }

    private var badgeText: String {
        if pendingCount > 99 {
            return "99+"
        }

        return "\(max(pendingCount, 1))"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Text(statusTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RemindersPalette.lightPrimaryText)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(RemindersPalette.accentRedLight, lineWidth: 2)
                            .frame(width: 16, height: 16)
                        Circle()
                            .fill(RemindersPalette.accentRedLight)
                            .frame(width: 6, height: 6)
                    }

                    Text(badgeText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, badgeText.count > 1 ? 4 : 0)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(RemindersPalette.accentRedLight)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 25)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xF6F6F6), Color(hex: 0xE8E8E8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            HStack {
                Spacer()
                ReminderPopupView(
                    reminder: reminder,
                    onDismiss: onDismiss,
                    onSnooze: onSnooze,
                    onComplete: onComplete
                )
            }
            .padding(.top, 8)
            .padding(.horizontal, 100)
        }
        .frame(width: 400, height: 200, alignment: .top)
        .background(Color.clear)
    }
}
