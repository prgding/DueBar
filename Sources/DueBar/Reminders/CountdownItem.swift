import Foundation
import CoreGraphics
import SwiftUI

/// A reminder with a due date, reduced to a `Sendable` value type so it can
/// safely cross actor boundaries — `EKReminder` itself is not Sendable. We build
/// these inside the EventKit fetch callback (an arbitrary queue) and hand only
/// these to the main actor; the views and menu-bar renderer never touch EventKit.
///
/// `daysLeft` is intentionally *not* stored: it depends on "today", which rolls
/// over at midnight, so callers compute it fresh via `DueMath` against the
/// current date at render time.
struct CountdownItem: Identifiable, Sendable, Hashable {
    /// `EKReminder.calendarItemIdentifier` — used as the list id and for the
    /// "jump to Reminders" deep link.
    let id: String
    let title: String
    /// Resolved from `dueDateComponents`. If the reminder had no time-of-day,
    /// this is the start of the due day.
    let due: Date
    /// Whether the reminder carried an explicit time (hour/minute) component.
    let hasTime: Bool
    /// `EKCalendar.calendarIdentifier` of the owning list — used by the list filter.
    let listID: String
    let listName: String
    /// The reminder's list (calendar) color, decomposed so the struct stays
    /// Sendable without depending on `NSColor` (which is main-thread-only).
    let listColor: RGBA
}

/// A reminder list (an `EKCalendar`), surfaced to the settings filter UI.
struct ReminderList: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let color: RGBA
}

/// Plain Sendable color carrier. Keeping raw sRGB components avoids round-tripping
/// through `NSColor`/`Color` off the main thread inside the fetch callback.
struct RGBA: Sendable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    /// Built lazily on the main thread when a view needs to draw the swatch.
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    static let neutral = RGBA(r: 0.55, g: 0.55, b: 0.55, a: 1)
}

extension RGBA {
    /// Decompose a `CGColor` into sRGB components. `CGColor` conversion is
    /// thread-safe (unlike `NSColor`), so this is callable from the fetch queue.
    init(cgColor: CGColor?) {
        guard let cg = cgColor,
              let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cg.converted(to: srgb, intent: .defaultIntent, options: nil),
              let c = converted.components, c.count >= 3 else {
            self = .neutral
            return
        }
        self.init(r: Double(c[0]), g: Double(c[1]), b: Double(c[2]),
                  a: Double(c.count >= 4 ? c[3] : 1))
    }
}
