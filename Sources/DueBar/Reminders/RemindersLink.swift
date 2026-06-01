import AppKit

/// Best-effort "jump to Reminders.app". The per-item deep link
/// (`x-apple-reminderkit://REMCDReminder/<UUID>`) is undocumented and its UUID
/// may not match EventKit's `calendarItemIdentifier` — so opening it both
/// launches the app *and* attempts to navigate; if navigation misses, the app
/// still comes to the front. A click is never a silent no-op.
enum RemindersLink {
    @MainActor
    static func open(_ item: CountdownItem) {
        if !item.id.isEmpty,
           let deep = URL(string: "x-apple-reminderkit://REMCDReminder/\(item.id)") {
            NSWorkspace.shared.open(deep)
        } else {
            openApp()
        }
    }

    /// Launch Reminders.app by bundle id — robust even if the URL scheme changes.
    @MainActor
    static func openApp() {
        guard let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: "com.apple.reminders") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
