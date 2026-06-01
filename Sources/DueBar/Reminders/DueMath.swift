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
}
