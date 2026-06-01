import SwiftUI

/// One reminder in the countdown list: list-color dot, title + (list · due date),
/// and an urgency-colored "还剩 N 天" badge. Tapping jumps to Reminders.app.
struct CountdownRow: View {
    let item: CountdownItem
    let now: Date

    private var daysLeft: Int { DueMath.daysLeft(from: now, to: item.due) }
    private var urgency: Urgency { DueMath.urgency(daysLeft: daysLeft) }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(item.listColor.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text("\(item.listName) · \(dueString)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(DueMath.countdownText(daysLeft: daysLeft))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { RemindersLink.open(item) }
        .help("在「提醒事项」中打开")
    }

    private var badgeColor: Color {
        switch urgency {
        case .overdue:  return .red
        case .imminent: return .orange
        case .soon:     return .primary
        case .later:    return .secondary
        }
    }

    private var dueString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = item.hasTime ? "M月d日 HH:mm" : "M月d日"
        return f.string(from: item.due)
    }
}
