import AppKit
import SwiftUI

@MainActor
final class ReminderSettingsWindowController {
    private var window: NSWindow?

    func showWindow() {
        let window = self.window ?? makeWindow()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: ReminderSettingsView())
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: ReminderSettingsView.preferredWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "提醒设置"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("ReminderSettingsWindow")
        window.contentViewController = hostingController
        window.contentMinSize = ReminderSettingsView.preferredWindowSize
        window.contentMaxSize = ReminderSettingsView.preferredWindowSize
        window.standardWindowButton(.zoomButton)?.isHidden = true
        return window
    }
}
