import Carbon
import Foundation
@testable import ClipShelfCore

func placementTests() {
    let size = CGSize(width: 400, height: 480)
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 875) // visible frame, below the menu bar

    suite("PanelPlacement") {
        test("below the menu bar icon, centered") {
            let icon = CGRect(x: 1000, y: 875, width: 24, height: 24)
            let o = PanelPlacement.origin(size: size, anchor: icon, mouse: .zero, visibleFrame: screen)
            expectEqual(o.x, 1012 - 200)
            expectEqual(o.y, 875 - 480 - 8, "clamped just under the menu bar")
        }

        test("menu bar icon near the right edge stays on screen") {
            let icon = CGRect(x: 1420, y: 875, width: 20, height: 24)
            let o = PanelPlacement.origin(size: size, anchor: icon, mouse: .zero, visibleFrame: screen)
            expectEqual(o.x, 1440 - 400 - 8)
        }

        test("at the mouse: top-left corner near the cursor") {
            let o = PanelPlacement.origin(size: size, anchor: nil, mouse: CGPoint(x: 500, y: 700), visibleFrame: screen)
            expectEqual(o, CGPoint(x: 480, y: 700 - 480 + 20))
        }

        test("mouse near the bottom-left corner pushes the panel up and right") {
            let o = PanelPlacement.origin(size: size, anchor: nil, mouse: CGPoint(x: 2, y: 30), visibleFrame: screen)
            expectEqual(o, CGPoint(x: 8, y: 8))
        }

        test("works on a secondary screen left of / below the main one") {
            let second = CGRect(x: -1920, y: -300, width: 1920, height: 1080)
            let o = PanelPlacement.origin(size: size, anchor: nil, mouse: CGPoint(x: -100, y: -250), visibleFrame: second)
            expect(second.contains(CGRect(origin: o, size: size)), "\(o) not inside \(second)")
        }

        test("panel taller than the screen keeps its top edge visible") {
            let small = CGRect(x: 0, y: 0, width: 800, height: 300)
            let o = PanelPlacement.origin(size: size, anchor: nil, mouse: CGPoint(x: 100, y: 100), visibleFrame: small)
            expectEqual(o.y + size.height, 300 - 8)
        }

        test("always fully on screen for a grid of mouse positions") {
            for x in stride(from: -50.0, through: 1500, by: 97) {
                for y in stride(from: -50.0, through: 950, by: 83) {
                    let o = PanelPlacement.origin(size: size, anchor: nil, mouse: CGPoint(x: x, y: y), visibleFrame: screen)
                    expect(screen.contains(CGRect(origin: o, size: size)), "mouse (\(x), \(y)) → \(o)")
                }
            }
        }
    }
}

func hotKeyTests() {
    suite("HotKey") {
        test("defaults to ⇧⌘V and remembers the choice") {
            let env = TestEnv()
            expectEqual(HotKeyPreset.current(in: env.defaults), .cmdShiftV)
            HotKeyPreset.setCurrent(.ctrlCmdV, in: env.defaults)
            expectEqual(HotKeyPreset.current(in: env.defaults), .ctrlCmdV)
        }

        test("an unknown stored value falls back to the default") {
            let env = TestEnv()
            env.defaults.set("garbage", forKey: "hotkey")
            expectEqual(HotKeyPreset.current(in: env.defaults), .cmdShiftV)
        }

        test("presets are all V with distinct modifiers and titles") {
            let all = HotKeyPreset.allCases
            expect(all.allSatisfy { $0.keyCode == UInt32(kVK_ANSI_V) })
            expect(all.allSatisfy { $0.modifiers & UInt32(cmdKey) != 0 }, "all include ⌘")
            expectEqual(Set(all.map(\.modifiers)).count, all.count)
            expectEqual(Set(all.map(\.title)).count, all.count)
        }

        test("registers, rejects a duplicate, and unregisters on release") {
            // An unusual combo so it can't clash with anything on the machine running the tests.
            let key = UInt32(kVK_F19)
            let mods = UInt32(cmdKey | optionKey | controlKey | shiftKey)
            var first: HotKey? = HotKey(keyCode: key, modifiers: mods) {}
            expect(first?.isRegistered == true, "first registration")
            let duplicate = HotKey(keyCode: key, modifiers: mods) {}
            expect(!duplicate.isRegistered, "same shortcut twice should fail")
            first = nil
            let again = HotKey(keyCode: key, modifiers: mods) {}
            expect(again.isRegistered, "free again after the first was released")
        }
    }
}
