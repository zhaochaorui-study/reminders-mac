import AppKit
import SwiftUI

@main
struct RemindersMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 需要至少一个 Scene，用 Settings 占位
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ReminderStore?
    private var menuBarController: MenuBarController?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let s = ReminderStore()
        self.store = s
        self.menuBarController = MenuBarController(store: s)
    }
}
