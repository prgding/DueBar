import SwiftUI
import AppKit

/// Root of the popover. Switches between the countdown list and the settings page
/// (inline, no sheets), and gates the list behind the EventKit authorization state.
struct PopoverRootView: View {
    /// Single source of truth for the popover size — `AppDelegate` sets the
    /// `NSPopover.contentSize` to this too, so the window and the SwiftUI frame
    /// can't drift (a mismatch is what clips the popover on first show).
    static let popoverSize = CGSize(width: 320, height: 440)

    @Environment(RemindersService.self) private var service
    @Environment(SettingsStore.self) private var settings
    @Environment(PopoverNavigator.self) private var nav

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch nav.page {
            case .list:
                listHeader
                Divider()
                listContent
                Divider()
                footer
            case .settings:
                settingsHeader
                Divider()
                SettingsView()
            }
        }
        .frame(width: Self.popoverSize.width, height: Self.popoverSize.height)
    }

    // MARK: List page

    private var listHeader: some View {
        HStack {
            Text("倒数日").font(.system(size: 13, weight: .semibold))
            Spacer()
            if case .granted = service.access {
                Text("\(service.items.count) 项")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    @ViewBuilder
    private var listContent: some View {
        switch service.access {
        case .granted:
            if service.items.isEmpty {
                centered(icon: "checkmark.circle", text: "没有带截止日期的待办事项")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(service.items) { item in
                            CountdownRow(item: item, now: Date())
                            Divider().padding(.leading, 30)
                        }
                    }
                }
            }
        case .notDetermined, .unknown:
            prompt(icon: "lock.circle",
                   text: "DueBar 需要访问你的提醒事项，\n才能算出每项还剩多少天。",
                   button: "授权访问") { Task { await service.requestAccess() } }
        case .denied:
            prompt(icon: "lock.slash",
                   text: "提醒事项访问被拒绝。\n请在系统设置中允许 DueBar 访问。",
                   button: "打开系统设置") { openPrivacySettings() }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let ts = service.lastRefresh {
                Text("更新于 \(timeString(ts))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await service.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
            }.buttonStyle(.borderless).help("刷新")
            Button { nav.page = .settings } label: {
                Image(systemName: "gearshape")
            }.buttonStyle(.borderless).help("设置")
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
            }.buttonStyle(.borderless).help("退出 DueBar")
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    // MARK: Settings page header

    private var settingsHeader: some View {
        HStack {
            Button { nav.page = .list } label: {
                HStack(spacing: 2) { Image(systemName: "chevron.left"); Text("返回") }
            }.buttonStyle(.borderless)
            Spacer()
            Text("设置").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Color.clear.frame(width: 44, height: 1)   // balance the back button
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: Shared bits

    @ViewBuilder
    private func centered(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func prompt(icon: String, text: String, button: String,
                        action: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon).font(.system(size: 34)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Button(button, action: action).buttonStyle(.borderedProminent)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }
}
