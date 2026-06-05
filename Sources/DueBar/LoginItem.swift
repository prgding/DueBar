import Foundation
import ServiceManagement

/// Wraps the macOS 13+ login-item API (`SMAppService.mainApp`). Registering adds
/// DueBar to System Settings → General → Login Items so it launches at login;
/// `SMAppService`'s own status (persisted in Background Task Management) is the
/// source of truth, so there's no separate UserDefault to keep in sync.
enum LoginItem {
    @MainActor static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @MainActor static func setEnabled(_ enabled: Bool) throws {
        let svc = SMAppService.mainApp
        switch (enabled, svc.status) {
        case (true, .enabled):   break               // already on
        case (true, _):          try svc.register()
        case (false, .enabled):  try svc.unregister()
        case (false, _):         break               // already off
        }
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered:    return "notRegistered"
        case .enabled:          return "enabled"
        case .requiresApproval: return "requiresApproval (去登录项里批准)"
        case .notFound:         return "notFound"
        @unknown default:       return "unknown(\(SMAppService.mainApp.status.rawValue))"
        }
    }

    /// Backs the `--register-login` / `--unregister-login` CLI flags so the login
    /// item can be toggled without opening the popover (used by Scripts + manual
    /// runs). Prints the resulting status and exits.
    @MainActor static func runCLI(enable: Bool) -> Never {
        do { try setEnabled(enable) }
        catch { FileHandle.standardError.write(Data("login-item error: \(error)\n".utf8)) }
        FileHandle.standardOutput.write(Data("login-item: \(statusDescription)\n".utf8))
        exit(0)
    }
}
