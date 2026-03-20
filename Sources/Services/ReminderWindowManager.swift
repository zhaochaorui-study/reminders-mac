import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class ReminderWindowManager {
    private enum Constants {
        static let reminderPanelSize = NSSize(width: 320, height: 160)
        static let advancePanelSize = NSSize(width: 300, height: 118)
        static let panelMargin: CGFloat = 20
        static let panelSpacing: CGFloat = 12
        static let panelStackHeight: CGFloat = reminderPanelSize.height + panelSpacing
        static let reminderAppearDuration: TimeInterval = 0.24
        static let reminderDisappearDuration: TimeInterval = 0.18
        static let reminderInitialScale: CGFloat = 0.94
        static let reminderDismissScale: CGFloat = 0.96
        static let advanceDisplayDuration: TimeInterval = 5
        static let advanceFadeInDuration: TimeInterval = 0.22
        static let advanceFadeOutDuration: TimeInterval = 0.3
    }

    var onComplete: ((UUID) -> Void)?
    var onSnooze: ((UUID, SnoozeOption) -> Void)?
    var onDismiss: ((UUID) -> Void)?

    private var activeWindows: [UUID: NSPanel] = [:]
    private var activeAdvanceWindows: [UUID: NSPanel] = [:]

    func showReminder(_ item: ReminderItem) {
        NSLog("[窗口] showReminder 被调用: %@, id: %@", item.title, "\(item.id)")
        dismissAdvanceNotice(for: item.id)

        if let existingWindow = activeWindows[item.id] {
            existingWindow.orderFrontRegardless()
            NSSound.beep()
            return
        }

        let reminderID = item.id
        let panel = makePanel(
            size: Constants.reminderPanelSize,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView]
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = NSHostingView(
            rootView: ReminderAlertContentView(
                title: item.title,
                scheduleText: item.scheduleText,
                onComplete: { [weak self] in
                    self?.dismissWindow(for: reminderID)
                    self?.onComplete?(reminderID)
                },
                onSnooze: { [weak self] option in
                    self?.dismissWindow(for: reminderID)
                    self?.onSnooze?(reminderID, option)
                },
                onDismiss: { [weak self] in
                    self?.dismissWindow(for: reminderID)
                    self?.onDismiss?(reminderID)
                }
            )
        )

        position(panel, stackIndex: activeWindows.count + activeAdvanceWindows.count)
        prepareReminderPanelForPresentation(panel)
        panel.orderFrontRegardless()
        animateReminderPanelPresentation(panel)
        NSSound.beep()
        activeWindows[reminderID] = panel
    }

    func showAdvanceNotice(for item: ReminderItem, remainingMinutes: Int) {
        guard activeWindows[item.id] == nil else {
            return
        }

        if let existingWindow = activeAdvanceWindows[item.id] {
            existingWindow.orderFrontRegardless()
            return
        }

        let reminderID = item.id
        let panel = makePanel(
            size: Constants.advancePanelSize,
            styleMask: [.nonactivatingPanel, .borderless]
        )
        panel.alphaValue = 0
        panel.contentView = NSHostingView(
            rootView: AdvanceReminderContentView(
                title: item.title,
                remainingText: Self.remainingText(for: remainingMinutes),
                scheduleText: item.scheduleText
            )
        )

        position(panel, stackIndex: activeWindows.count + activeAdvanceWindows.count)
        panel.orderFrontRegardless()
        activeAdvanceWindows[reminderID] = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.advanceFadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.advanceDisplayDuration) { [weak self, weak panel] in
            guard let self,
                  let panel,
                  self.activeAdvanceWindows[reminderID] === panel
            else {
                return
            }

            NSAnimationContext.runAnimationGroup(
                { context in
                    context.duration = Constants.advanceFadeOutDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().alphaValue = 0
                },
                completionHandler: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.dismissAdvanceNotice(for: reminderID)
                    }
                }
            )
        }
    }

    func dismissWindow(for id: UUID) {
        dismissAdvanceNotice(for: id)

        guard let window = activeWindows.removeValue(forKey: id) else {
            return
        }

        animateReminderPanelDismissal(window)
    }

    func dismissAdvanceNotice(for id: UUID) {
        guard let window = activeAdvanceWindows.removeValue(forKey: id) else {
            return
        }

        closePanel(window)
    }

    func dismissAll() {
        for (_, window) in activeWindows {
            animateReminderPanelDismissal(window)
        }
        activeWindows.removeAll()

        for (_, window) in activeAdvanceWindows {
            window.orderOut(nil)
            window.close()
        }
        activeAdvanceWindows.removeAll()
    }

    private func makePanel(size: NSSize, styleMask: NSWindow.StyleMask) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        return panel
    }

    private func prepareReminderPanelForPresentation(_ panel: NSPanel) {
        panel.alphaValue = 0
        setReminderPanelScale(panel, scale: Constants.reminderInitialScale, disableActions: true)
    }

    private func animateReminderPanelPresentation(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.reminderAppearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            animateReminderPanelScale(panel, scale: 1, duration: Constants.reminderAppearDuration)
        }
    }

    private func animateReminderPanelDismissal(_ panel: NSPanel) {
        guard panel.isVisible else {
            closePanel(panel)
            return
        }

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = Constants.reminderDisappearDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0
                animateReminderPanelScale(panel, scale: Constants.reminderDismissScale, duration: Constants.reminderDisappearDuration)
            },
            completionHandler: { [weak self, weak panel] in
                Task { @MainActor [weak self, weak panel] in
                    guard let self, let panel else {
                        return
                    }

                    self.closePanel(panel)
                }
            }
        )
    }

    private func closePanel(_ panel: NSPanel) {
        panel.orderOut(nil)
        panel.close()
    }

    private func animateReminderPanelScale(_ panel: NSPanel, scale: CGFloat, duration: TimeInterval) {
        setReminderPanelScale(panel, scale: scale, disableActions: false, duration: duration)
    }

    private func setReminderPanelScale(
        _ panel: NSPanel,
        scale: CGFloat,
        disableActions: Bool,
        duration: TimeInterval = 0
    ) {
        guard let contentView = panel.contentView else {
            return
        }

        contentView.wantsLayer = true
        guard let layer = contentView.layer else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(disableActions)
        if disableActions == false {
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        }
        layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }

    private func position(_ panel: NSPanel, stackIndex: Int) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame
        let x = screenFrame.maxX - panelFrame.width - Constants.panelMargin
        let y = screenFrame.maxY - panelFrame.height - Constants.panelMargin - (CGFloat(stackIndex) * Constants.panelStackHeight)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private static func remainingText(for minutes: Int) -> String {
        minutes <= 1 ? "不到 1 分钟后" : "\(minutes) 分钟后"
    }
}

private struct ReminderAlertContentView: View {
    let title: String
    let scheduleText: String
    let onComplete: () -> Void
    let onSnooze: (SnoozeOption) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.orange)
                    Text("待办提醒")
                        .font(.system(size: 13, weight: .semibold))
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)

                Text("预定时间：\(scheduleText)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            HStack(spacing: 10) {
                SnoozeOptionMenuButtonView(
                    title: "稍后提醒",
                    background: RemindersPalette.elevated,
                    foreground: RemindersPalette.primaryText,
                    onSelect: onSnooze
                )

                Button(action: onComplete) {
                    Text("标记完成")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 10)
    }
}

private struct AdvanceReminderContentView: View {
    let title: String
    let remainingText: String
    let scheduleText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)

                Text("预提醒")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)

            Text("\(remainingText) 提醒，计划时间：\(scheduleText)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 300, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 8)
    }
}
