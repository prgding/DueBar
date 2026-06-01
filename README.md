# DueBar

一个常驻菜单栏的「倒数日」小工具。它读取 **提醒事项 App（Reminders.app）** 里所有**未完成且带截止日期**的事项，按紧迫度列出每项「还剩 N 天 / 今天 / 已过期 N 天」——补足提醒事项本身不显示剩余天数的缺口。

DueBar 只**读取**数据、不修改：所有事项仍以 Reminders.app 为准。点击某一项会跳转到提醒事项 App。

## 功能

- 菜单栏图标区**可配置**显示：仅图标 / 图标 + 最近天数 / 标题 + 天数
- 弹窗列表按截止日期升序（最紧迫/已逾期在最上），紧迫度配色：逾期红、今明天橙、一周内主色、更远次要色
- 设置：按提醒列表筛选、是否显示已过期、时间范围（全部 / 7 / 30 / 90 天内）
- 外部在提醒事项里增删改后自动刷新（监听 `EKEventStoreChanged`），并每 10 分钟重算一次（兜住跨午夜的天数滚动）

## 构建与运行

需要 macOS 14+ 与 Swift 6 工具链。菜单栏应用必须以 `.app` 形式启动（终端裸跑二进制不会显示菜单栏项）。

```bash
Scripts/package_app.sh && open build/DueBar.app
```

`package_app.sh` 会 `swift build -c release`、打成 `build/DueBar.app` 并做 ad-hoc 签名。

首次点击菜单栏图标时，弹窗会请求**提醒事项**访问权限；点「授权访问」并在系统弹窗里允许即可。

## 已知限制

- **点击跳转**用的是未公开的 `x-apple-reminderkit://REMCDReminder/<id>` scheme，其内部 UUID 与 EventKit 的 `calendarItemIdentifier` 不一定一致；若无法精确定位到那一条，会退化为把提醒事项 App 唤到前台。
- **ad-hoc 签名**：每次重新构建，代码签名的 cdhash 会变，macOS 可能再次弹出权限请求。个人自用可接受；若想让授权在重建间保持，可改用稳定的自签证书重新签名。
- 未沙盒化、未公证；自用工具，不面向分发。

## 结构

```
Sources/DueBar/
  main.swift                 # .app 守卫 + NSApplication(.accessory) 启动
  AppDelegate.swift          # NSStatusItem + NSPopover；刷新调度；菜单栏 label
  Reminders/
    RemindersService.swift   # EventKit 鉴权 + 拉取 + 映射 + 变更监听
    CountdownItem.swift       # Sendable 值类型 + 列表色 RGBA + ReminderList
    DueMath.swift            # 纯函数：剩余天数 / 文案 / 紧迫度
    RemindersLink.swift      # 跳转提醒事项（深链 + 兜底）
  Settings/SettingsStore.swift  # UserDefaults：labelMode / 筛选项
  MenuBar/LabelRenderer.swift   # 按 labelMode 渲染状态栏按钮
  Views/                     # SwiftUI 弹窗：导航、列表、行、设置页
```
