import Carbon
import Foundation

/// A system-wide keyboard shortcut using the Carbon hot key API
/// (works without Accessibility permission).
public final class HotKey {
    private var ref: EventHotKeyRef?
    private let id: UInt32

    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    /// False if the shortcut couldn't be registered, e.g. because another app already owns it.
    public var isRegistered: Bool { ref != nil }

    public init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        HotKey.installHandlerIfNeeded()
        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.handlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_5346), id: id) // "CLSF"
        if RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref) != noErr {
            ref = nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            HotKey.handlers[hotKeyID.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }
}

/// The shortcut choices offered in the menu.
public enum HotKeyPreset: String, CaseIterable {
    case cmdShiftV, ctrlCmdV, optCmdV

    public var title: String {
        switch self {
        case .cmdShiftV: return "⇧⌘V"
        case .ctrlCmdV: return "⌃⌘V"
        case .optCmdV: return "⌥⌘V"
        }
    }

    public var modifiers: UInt32 {
        switch self {
        case .cmdShiftV: return UInt32(cmdKey | shiftKey)
        case .ctrlCmdV: return UInt32(cmdKey | controlKey)
        case .optCmdV: return UInt32(cmdKey | optionKey)
        }
    }

    public var keyCode: UInt32 { UInt32(kVK_ANSI_V) }

    public static func current(in defaults: UserDefaults = .standard) -> HotKeyPreset {
        HotKeyPreset(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .cmdShiftV
    }

    public static func setCurrent(_ preset: HotKeyPreset, in defaults: UserDefaults = .standard) {
        defaults.set(preset.rawValue, forKey: "hotkey")
    }
}
