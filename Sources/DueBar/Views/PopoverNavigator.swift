import SwiftUI
import Observation

/// Which page the popover shows. We use inline pages rather than `.sheet`/
/// `.popover` — a child window inside a status-bar popover steals focus and
/// dismisses it. `AppDelegate`'s ESC monitor also reads/writes this.
enum PopoverPage: Equatable {
    case list
    case settings
}

@MainActor
@Observable
final class PopoverNavigator {
    var page: PopoverPage = .list
}
