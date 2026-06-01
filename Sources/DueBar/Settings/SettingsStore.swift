import Foundation
import Observation

/// What the menu bar status item shows. User-switchable in settings.
enum LabelMode: String, CaseIterable, Sendable {
    case iconOnly
    case iconAndDays
    case titleAndDays

    var label: String {
        switch self {
        case .iconOnly:     return "仅图标"
        case .iconAndDays:  return "图标 + 天数"
        case .titleAndDays: return "标题 + 天数"
        }
    }
}

/// Persisted user preferences, backed by `UserDefaults`. `@Observable` so SwiftUI
/// settings controls update live; mutations also fire `onChange` so the AppKit
/// status item (which can't observe `@Observable`) re-derives.
@MainActor
@Observable
final class SettingsStore {
    private(set) var labelMode: LabelMode
    private(set) var includeOverdue: Bool
    /// `nil` = show every list. Otherwise the set of `EKCalendar` identifiers to show.
    private(set) var selectedListIDs: Set<String>?
    /// `nil` = no horizon (show all upcoming). Otherwise only items due within N
    /// days. Overdue items are governed by `includeOverdue`, not the horizon.
    private(set) var horizonDays: Int?

    /// Set by `AppDelegate`. Fires after any change so the status item + list re-derive.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    private let defaults = UserDefaults.standard

    init() {
        labelMode = LabelMode(rawValue: defaults.string(forKey: K.labelMode) ?? "") ?? .iconAndDays
        includeOverdue = defaults.object(forKey: K.includeOverdue) as? Bool ?? true
        if let ids = defaults.array(forKey: K.selectedListIDs) as? [String] {
            selectedListIDs = Set(ids)
        } else {
            selectedListIDs = nil
        }
        let h = defaults.integer(forKey: K.horizonDays)
        horizonDays = h > 0 ? h : nil
    }

    // MARK: Mutators (persist + notify)

    func setLabelMode(_ m: LabelMode) {
        labelMode = m
        defaults.set(m.rawValue, forKey: K.labelMode)
        onChange?()
    }

    func setIncludeOverdue(_ v: Bool) {
        includeOverdue = v
        defaults.set(v, forKey: K.includeOverdue)
        onChange?()
    }

    func setHorizon(_ days: Int?) {
        horizonDays = (days ?? 0) > 0 ? days : nil
        if let d = horizonDays { defaults.set(d, forKey: K.horizonDays) }
        else { defaults.removeObject(forKey: K.horizonDays) }
        onChange?()
    }

    /// `nil` resets to "all lists".
    func setSelectedLists(_ ids: Set<String>?) {
        selectedListIDs = ids
        if let ids { defaults.set(Array(ids), forKey: K.selectedListIDs) }
        else { defaults.removeObject(forKey: K.selectedListIDs) }
        onChange?()
    }

    /// Flip one list on/off. The first deselection materializes the implicit
    /// "all" into an explicit set; re-selecting everything collapses back to `nil`.
    func toggleList(_ id: String, allListIDs: [String]) {
        var current = selectedListIDs ?? Set(allListIDs)
        if current.contains(id) { current.remove(id) } else { current.insert(id) }
        setSelectedLists(current == Set(allListIDs) ? nil : current)
    }

    func isListSelected(_ id: String) -> Bool {
        selectedListIDs?.contains(id) ?? true
    }

    private enum K {
        static let labelMode = "labelMode"
        static let includeOverdue = "includeOverdue"
        static let selectedListIDs = "selectedListIDs"
        static let horizonDays = "horizonDays"
    }
}
