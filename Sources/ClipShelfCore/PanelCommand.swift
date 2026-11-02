import AppKit

/// Keyboard commands understood by the clipboard panel.
public enum PanelCommand: Equatable {
    case close
    case clearSearch
    case moveUp, moveDown, moveToTop, moveToBottom
    case paste
    case copy
    case togglePin
    case delete
    case pasteItem(at: Int)
}

public enum KeyCode {
    public static let returnKey: UInt16 = 36
    public static let keypadEnter: UInt16 = 76
    public static let delete: UInt16 = 51
    public static let escape: UInt16 = 53
    public static let home: UInt16 = 115
    public static let end: UInt16 = 119
    public static let down: UInt16 = 125
    public static let up: UInt16 = 126
}

extension PanelCommand {
    /// Maps a key press to a command, or nil to let the search field handle it (typing, ⌘A, ⌘V, …).
    public static func from(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String?,
                            queryIsEmpty: Bool, searchHasSelection: Bool) -> PanelCommand? {
        let mods = modifiers.intersection([.command, .shift, .option, .control])

        switch keyCode {
        case KeyCode.escape:
            return queryIsEmpty ? .close : .clearSearch
        case KeyCode.down:
            return mods.contains(.command) ? .moveToBottom : .moveDown
        case KeyCode.up:
            return mods.contains(.command) ? .moveToTop : .moveUp
        case KeyCode.home:
            return .moveToTop
        case KeyCode.end:
            return .moveToBottom
        case KeyCode.returnKey, KeyCode.keypadEnter:
            return mods.contains(.shift) ? .copy : .paste
        default:
            break
        }

        guard mods == .command else { return nil }
        if keyCode == KeyCode.delete { return .delete }

        switch characters?.lowercased() {
        case "p":
            return .togglePin
        case "c":
            // ⌘C with text selected in the search field copies that text instead.
            return searchHasSelection ? nil : .copy
        case let s? where s.count == 1 && ("1"..."9").contains(s):
            return .pasteItem(at: Int(s)! - 1)
        default:
            return nil
        }
    }
}
