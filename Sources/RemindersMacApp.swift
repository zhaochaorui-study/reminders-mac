import AppKit
import SwiftUI

@main
struct RemindersMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ReminderStore?
    private var menuBarController: MenuBarController?
    private let settingsWindowController = ReminderSettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let s = ReminderStore()
        self.store = s
        self.menuBarController = MenuBarController(
            store: s,
            onShowSettings: { [weak self] in
                self?.settingsWindowController.showWindow()
            }
        )
    }
}
