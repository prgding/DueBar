import AppKit

/// Configures the status item's button for the current `LabelMode`. The menu bar
/// renders template images as monochrome (alpha-only), so urgency *color* lives
/// only in the popover — here we keep to an icon and/or a short text token.
enum LabelRenderer {
    @MainActor
    static func render(button: NSStatusBarButton,
                       mode: LabelMode,
                       nearest: CountdownItem?,
                       now: Date = Date()) {
        let symbol = NSImage(systemSymbolName: "calendar.badge.clock",
                             accessibilityDescription: "DueBar")
        symbol?.isTemplate = true
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        switch mode {
        case .iconOnly:
            button.image = symbol
            button.title = ""
            button.imagePosition = .imageOnly

        case .iconAndDays:
            button.image = symbol
            if let item = nearest {
                button.title = " " + token(for: item, now: now)
                button.imagePosition = .imageLeading
            } else {
                button.title = ""
                button.imagePosition = .imageOnly
            }

        case .titleAndDays:
            if let item = nearest {
                button.image = nil
                button.title = truncate(item.title, max: 8) + "·" + token(for: item, now: now)
                button.imagePosition = .noImage
            } else {
                button.image = symbol
                button.title = ""
                button.imagePosition = .imageOnly
            }
        }
    }

    private static func token(for item: CountdownItem, now: Date) -> String {
        DueMath.menuBarToken(now: now, due: item.due, hasTime: item.hasTime)
    }

    private static func truncate(_ s: String, max: Int) -> String {
        s.count <= max ? s : String(s.prefix(max)) + "…"
    }
}
