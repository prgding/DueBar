import Foundation
import EventKit
import Observation

/// Reads incomplete, due-dated reminders from EventKit and publishes them as
/// `Sendable` `CountdownItem`s. Lives on the main actor (so SwiftUI and the
/// status item can read it directly); the only off-main work is the EventKit
/// fetch callback, where reminders are mapped to value types before crossing back.
@MainActor
@Observable
final class RemindersService {
    enum Access: Sendable {
        case unknown        // not yet checked
        case notDetermined  // can prompt
        case denied         // user declined / restricted / write-only
        case granted        // full access
    }

    private(set) var access: Access = .unknown
    /// Filtered + sorted countdowns, as shown in the popover and menu bar.
    private(set) var items: [CountdownItem] = []
    /// Every reminder list, for the settings filter UI.
    private(set) var lists: [ReminderList] = []
    private(set) var lastRefresh: Date?
    private(set) var lastError: String?

    /// Set by `AppDelegate`: fires on the main actor whenever `items` changes, so
    /// the AppKit status item can re-render (AppKit can't observe `@Observable`).
    @ObservationIgnored var onItemsChanged: (@MainActor () -> Void)?

    private let store = EKEventStore()
    private let settings: SettingsStore
    /// Unfiltered fetch result; `refilter()` derives `items` from this without
    /// hitting EventKit again.
    private var rawItems: [CountdownItem] = []
    @ObservationIgnored private var changeObserver: (any NSObjectProtocol)?

    init(settings: SettingsStore) {
        self.settings = settings
        // External edits in Reminders.app post this; re-fetch when they land.
        // The class is @MainActor (hence Sendable), so capturing self in the
        // @Sendable observer block is allowed; we hop to the main actor to refresh.
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: Authorization

    /// Called once at launch: sync current status and fetch if already granted.
    func bootstrap() async {
        syncAccessStatus()
        if access == .granted { await refresh() }
    }

    /// Trigger the system permission prompt (only meaningful when `.notDetermined`).
    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToReminders()
            access = granted ? .granted : .denied
            if granted { await refresh() }
        } catch {
            lastError = error.localizedDescription
            access = .denied
        }
    }

    private func syncAccessStatus() {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined:                      access = .notDetermined
        case .fullAccess:                         access = .granted
        case .denied, .restricted, .writeOnly:    access = .denied
        @unknown default:                         access = .denied
        }
    }

    // MARK: Fetch / filter

    /// Re-fetch from EventKit, then re-derive the visible list.
    func refresh() async {
        guard access == .granted else { return }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil)
        rawItems = await fetch(matching: predicate)
        lists = store.calendars(for: .reminder).map {
            ReminderList(id: $0.calendarIdentifier, name: $0.title, color: RGBA(cgColor: $0.cgColor))
        }
        lastRefresh = Date()
        refilter()
    }

    /// Re-derive `items` from `rawItems` per current settings — no EventKit hit.
    /// Cheap, so it's safe to call on any settings change (incl. label-only ones).
    func refilter() {
        let now = Date()
        var result = rawItems

        if let selected = settings.selectedListIDs {
            result = result.filter { selected.contains($0.listID) }
        }
        if !settings.includeOverdue {
            result = result.filter { DueMath.daysLeft(from: now, to: $0.due) >= 0 }
        }
        if let horizon = settings.horizonDays {
            result = result.filter {
                let d = DueMath.daysLeft(from: now, to: $0.due)
                return d < 0 || d <= horizon   // keep overdue; cap upcoming
            }
        }

        result.sort { $0.due < $1.due }   // soonest / most overdue first
        items = result
        onItemsChanged?()
    }

    /// The most urgent shown item (top of the sorted list), for the menu-bar label.
    var nearest: CountdownItem? { items.first }

    // MARK: EventKit bridging

    /// Wrap the callback-based fetch in async. The completion runs on an arbitrary
    /// queue: we map each `EKReminder` to a Sendable `CountdownItem` *inside* the
    /// closure and only carry those across — never the EventKit objects themselves.
    private func fetch(matching predicate: NSPredicate) async -> [CountdownItem] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).compactMap(Self.map)
                continuation.resume(returning: mapped)
            }
        }
    }

    /// `nonisolated` so it's callable from the off-main fetch callback. Reads only
    /// the reminder (safe in the completion handler) and returns a value type.
    nonisolated static func map(_ reminder: EKReminder) -> CountdownItem? {
        guard let comps = reminder.dueDateComponents,
              let due = Calendar.current.date(from: comps) else { return nil }
        let cal: EKCalendar? = reminder.calendar
        return CountdownItem(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "(无标题)",
            due: due,
            hasTime: comps.hour != nil || comps.minute != nil,
            listID: cal?.calendarIdentifier ?? "",
            listName: cal?.title ?? "",
            listColor: RGBA(cgColor: cal?.cgColor)
        )
    }
}
