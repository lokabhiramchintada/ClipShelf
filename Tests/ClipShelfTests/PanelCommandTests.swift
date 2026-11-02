import AppKit
@testable import ClipShelfCore

func panelCommandTests() {
    func command(_ keyCode: UInt16, _ mods: NSEvent.ModifierFlags = [], _ chars: String? = nil,
                 queryIsEmpty: Bool = true, searchHasSelection: Bool = false) -> PanelCommand? {
        PanelCommand.from(keyCode: keyCode, modifiers: mods, characters: chars,
                          queryIsEmpty: queryIsEmpty, searchHasSelection: searchHasSelection)
    }

    // Virtual key codes for letters/digits used below.
    let kP: UInt16 = 35, kC: UInt16 = 8, kA: UInt16 = 0, kV: UInt16 = 9, k1: UInt16 = 18, k9: UInt16 = 25, k0: UInt16 = 29

    suite("PanelCommand (keyboard shortcuts)") {
        test("escape clears the search first, then closes") {
            expectEqual(command(KeyCode.escape, queryIsEmpty: false), .clearSearch)
            expectEqual(command(KeyCode.escape), .close)
        }

        test("arrows navigate; ⌘↑/⌘↓, Home/End jump") {
            expectEqual(command(KeyCode.up), .moveUp)
            expectEqual(command(KeyCode.down), .moveDown)
            expectEqual(command(KeyCode.up, .command), .moveToTop)
            expectEqual(command(KeyCode.down, .command), .moveToBottom)
            expectEqual(command(KeyCode.home), .moveToTop)
            expectEqual(command(KeyCode.end), .moveToBottom)
        }

        test("arrow keys carry function/numericPad flags and still work") {
            expectEqual(command(KeyCode.down, [.function, .numericPad]), .moveDown)
        }

        test("return pastes, shift-return copies, keypad enter works") {
            expectEqual(command(KeyCode.returnKey), .paste)
            expectEqual(command(KeyCode.keypadEnter), .paste)
            expectEqual(command(KeyCode.returnKey, .shift), .copy)
        }

        test("⌘P pins, ⌘⌫ deletes, ⌘C copies") {
            expectEqual(command(kP, .command, "p"), .togglePin)
            expectEqual(command(KeyCode.delete, .command), .delete)
            expectEqual(command(kC, .command, "c"), .copy)
        }

        test("⌘C copies selected search text instead when there is a selection") {
            expect(command(kC, .command, "c", queryIsEmpty: false, searchHasSelection: true) == nil)
        }

        test("⌘1…⌘9 paste by position; ⌘0 does nothing") {
            expectEqual(command(k1, .command, "1"), .pasteItem(at: 0))
            expectEqual(command(k9, .command, "9"), .pasteItem(at: 8))
            expect(command(k0, .command, "0") == nil)
        }

        test("caps lock doesn't break ⌘P") {
            expectEqual(command(kP, [.command, .capsLock], "P"), .togglePin)
        }

        test("typing and text-editing keys go to the search field") {
            expect(command(kP, [], "p") == nil, "plain letters")
            expect(command(k1, [], "1") == nil, "plain digits")
            expect(command(KeyCode.delete) == nil, "backspace")
            expect(command(KeyCode.delete, .option) == nil, "⌥⌫ delete word")
            expect(command(kA, .command, "a") == nil, "⌘A select all")
            expect(command(kV, .command, "v") == nil, "⌘V paste into search")
        }

        test("extra modifiers don't trigger ⌘ shortcuts") {
            expect(command(kP, [.command, .shift], "p") == nil)
            expect(command(k1, [.command, .option], "1") == nil)
            expect(command(KeyCode.delete, [.command, .shift]) == nil)
        }
    }
}
