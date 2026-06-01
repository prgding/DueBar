import AppKit
import SwiftUI

/// Owns the `NSStatusItem` (so the menu-bar label can be richer than SwiftUI's
/// `MenuBarExtra` allows) and the `NSPopover` hosting the SwiftUI UI. Wires the
/// `@Observable` service/settings to the AppKit side via callbacks, since AppKit
/// can't observe `@Observable` directly.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var keyMonitor: Any?
    private var tickTimer: Timer?

    private let settings = SettingsStore()
    private lazy var service = RemindersService(settings: settings)
    private let navigator = PopoverNavigator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        // AppKit can't observe @Observable: re-render the label whenever items
        // change, and re-derive items whenever a setting changes.
        service.onItemsChanged = { [weak self] in self?.renderLabel() }
        settings.onChange = { [weak self] in self?.service.refilter() }

        renderLabel()                          // initial (empty) state
        Task { await service.bootstrap() }     // check auth + first fetch
        startTickTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.invalidate()
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func renderLabel() {
        guard let button = statusItem?.button else { return }
        LabelRenderer.render(button: button, mode: settings.labelMode, nearest: service.nearest)
    }

    // MARK: Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = true
        // Size the popover up-front. Without this the first show happens before
        // NSHostingController has laid out, and the popover opens clipped.
        popover.contentSize = PopoverRootView.popoverSize
        let root = PopoverRootView()
            .environment(service)
            .environment(settings)
            .environment(navigator)
        popover.contentViewController = NSHostingController(rootView: root)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            navigator.page = .list
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            Task { await service.refresh() }   // freshen on open
        }
    }

    // MARK: Periodic tick

    /// Recompute every 10 min so "还剩 N 天" rolls over after midnight even when
    /// Reminders.app posts no change notification. `refilter()` is cheap.
    private func startTickTimer() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.service.refilter()
                self.renderLabel()
            }
        }
    }

    // MARK: NSPopoverDelegate — transient close + ESC (mirrors Hearth)

    /// `.transient` alone doesn't reliably close in an LSUIElement app, so mirror
    /// it with a global mouse monitor. Clicks on the status item / inside the
    /// popover go to our own app and aren't seen here, so the toggle stays intact.
    func popoverWillShow(_ notification: Notification) {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.popover.performClose(nil) }
        }
        // ESC at the AppKit layer: on the settings page, consume it to go back to
        // the list; on the list page, let AppKit close the popover as usual.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == 53 else { return event }   // 53 = ESC
            // `assumeIsolated` must return a Sendable value (NSEvent isn't), so
            // decide *whether* to consume here and return the event outside.
            let consume = MainActor.assumeIsolated { () -> Bool in
                if self.navigator.page != .list {
                    self.navigator.page = .list
                    return true
                }
                return false
            }
            return consume ? nil : event
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
