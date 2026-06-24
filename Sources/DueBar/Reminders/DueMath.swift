import Foundation

/// How urgent a countdown is — drives the badge color in the popover.
enum Urgency: Sendable {
    case overdue    // 已过期
    case imminent   // 今天 / 明天
    case soon       // 2–7 天内
    case later      // 更晚
}

/// Pure date arithmetic and display formatting for countdowns. No EventKit, no
/// UIKit/AppKit state — easy to reason about and to unit test in isolation.
enum DueMath {
    /// Whole calendar days from the start of `now`'s day to the start of `due`'s
    /// day. Positive = future, 0 = today, negative = overdue.
    ///
    /// Time-of-day is deliberately ignored: a reminder due tonight at 23:00 and
    /// one due tomorrow at 01:00 should read "今天" and "明天", not both "还剩 0 天".
    static func daysLeft(from now: Date, to due: Date, calendar: Calendar = .current) -> Int {
        let startToday = calendar.startOfDay(for: now)
        let startDue = calendar.startOfDay(for: due)
        return calendar.dateComponents([.day], from: startToday, to: startDue).day ?? 0
    }

    static func urgency(daysLeft: Int) -> Urgency {
        switch daysLeft {
        case ..<0:   return .overdue
        case 0, 1:   return .imminent
        case 2...7:  return .soon
        default:     return .later
        }
    }

    /// Full badge label for the popover, e.g. "今天" / "明天" / "还剩 3 天" / "已过期 2 天".
    static func countdownText(daysLeft: Int) -> String {
        switch daysLeft {
        case 0:                  return "今天"
        case 1:                  return "明天"
        case let d where d > 0:  return "还剩 \(d) 天"
        default:                 return "已过期 \(-daysLeft) 天"
        }
    }

    /// Compact, space-free token for the menu bar, e.g. "今天" / "明天" / "3天" / "逾期2".
    static func menuBarToken(daysLeft: Int) -> String {
        switch daysLeft {
        case 0:                  return "今天"
        case 1:                  return "明天"
        case let d where d > 0:  return "\(d)天"
        default:                 return "逾期\(-daysLeft)"
        }
    }

    /// "HH:mm" remaining until `due` when a *timed* item is due within the next
    /// 24 hours (e.g. "07:23"), else nil. All-day items (no time) never get a
    /// sub-day countdown — their due moment is midnight, which isn't meaningful.
    static func hourMinuteRemaining(now: Date, due: Date, hasTime: Bool) -> String? {
        guard hasTime else { return nil }
        let interval = due.timeIntervalSince(now)
        guard interval > 0, interval < 24 * 3600 else { return nil }
        let minutes = Int(interval / 60)   // floor to the minute
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Badge text for the popover: the HH:mm countdown when due within 24h, else
    /// the day-based label ("今天" / "明天" / "还剩 N 天" / "已过期 N 天").
    static func badgeText(now: Date, due: Date, hasTime: Bool) -> String {
        hourMinuteRemaining(now: now, due: due, hasTime: hasTime)
            ?? countdownText(daysLeft: daysLeft(from: now, to: due))
    }

    /// Menu-bar token with the same within-24h countdown behavior.
    static func menuBarToken(now: Date, due: Date, hasTime: Bool) -> String {
        hourMinuteRemaining(now: now, due: due, hasTime: hasTime)
            ?? menuBarToken(daysLeft: daysLeft(from: now, to: due))
    }

    /// Weekday with a relative-week prefix, on the Chinese Monday-first week:
    /// this week → "本周五", next week → "下周二", anything else (incl. past) → "周五".
    static func weekdayLabel(for due: Date, now: Date, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.firstWeekday = 2   // Monday
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let name = names[cal.component(.weekday, from: due) - 1]   // .weekday: 1=Sun … 7=Sat
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start,
              let dueWeek = cal.dateInterval(of: .weekOfYear, for: due)?.start else { return name }
        // Both are week-start midnights, so the day gap is a clean multiple of 7
        // (robust across year boundaries, unlike subtracting weekOfYear fields).
        let weeks = (cal.dateComponents([.day], from: thisWeek, to: dueWeek).day ?? 0) / 7
        switch weeks {
        case 0:  return "本" + name
        case 1:  return "下" + name
        default: return name
        }
    }
}
