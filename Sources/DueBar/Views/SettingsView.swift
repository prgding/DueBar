import SwiftUI

/// Inline settings page: menu-bar label mode, filters, and per-list visibility.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(RemindersService.self) private var service

    private let horizons: [(name: String, value: Int?)] =
        [("全部", nil), ("7 天内", 7), ("30 天内", 30), ("90 天内", 90)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("菜单栏显示") {
                    Picker("", selection: Binding(
                        get: { settings.labelMode },
                        set: { settings.setLabelMode($0) }
                    )) {
                        ForEach(LabelMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                section("筛选") {
                    Toggle("显示已过期事项", isOn: Binding(
                        get: { settings.includeOverdue },
                        set: { settings.setIncludeOverdue($0) }
                    ))
                    .font(.system(size: 12))

                    HStack {
                        Text("时间范围").font(.system(size: 12))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { settings.horizonDays },
                            set: { settings.setHorizon($0) }
                        )) {
                            ForEach(horizons, id: \.value) { h in
                                Text(h.name).tag(h.value)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                    }
                }

                section("提醒列表") {
                    if service.lists.isEmpty {
                        Text("没有可用的提醒列表")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        ForEach(service.lists) { list in
                            listToggle(list)
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func listToggle(_ list: ReminderList) -> some View {
        let selected = settings.isListSelected(list.id)
        Button {
            settings.toggleList(list.id, allListIDs: service.lists.map(\.id))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Circle().fill(list.color.color).frame(width: 8, height: 8)
                Text(list.name).font(.system(size: 12))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
