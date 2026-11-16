import AppKit

/// Hold a modifier key and click a card to delete it straight away.
/// Which key (or none) is chosen from the menu bar → Quick Delete.
/// Control isn't offered (Control-click is right-click on a Mac) and Shift
/// isn't either (it already means "plain text" when pasting).
enum QuickDelete: String, CaseIterable {
    case off
    case option
    case command
    case optionCommand

    static let defaultsKey = "quickDeleteModifier"

    static var current: QuickDelete {
        get { QuickDelete(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .option }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .off: return []
        case .option: return [.option]
        case .command: return [.command]
        case .optionCommand: return [.option, .command]
        }
    }

    /// Short symbol form for hints, e.g. "⌥".
    var symbol: String {
        switch self {
        case .off: return ""
        case .option: return "⌥"
        case .command: return "⌘"
        case .optionCommand: return "⌥⌘"
        }
    }

    var menuTitle: String {
        switch self {
        case .off: return "Off"
        case .option: return "⌥ Option-Click"
        case .command: return "⌘ Command-Click"
        case .optionCommand: return "⌥⌘ Option-Command-Click"
        }
    }

    /// True when exactly this key combination is held (extra modifiers don't count,
    /// so e.g. ⇧⌥ doesn't delete when the setting is ⌥).
    func matches(_ flags: NSEvent.ModifierFlags) -> Bool {
        guard self != .off else { return false }
        return flags.intersection([.command, .option, .control, .shift]) == self.flags
    }
}
