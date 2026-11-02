import Foundation
@testable import ClipShelfCore

func panelModelTests() {
    /// A model whose store holds `recent` (newest first) and `pinned` items.
    func makeModel(recent: [String], pinned: [String] = [], env: TestEnv = TestEnv()) -> (PanelModel, TestEnv) {
        let store = env.makeStore()
        for text in pinned.reversed() {
            store.add(text)
            store.togglePin(store.items[0].id)
        }
        recent.reversed().forEach { store.add($0) }
        let model = PanelModel(store: store)
        model.reset()
        return (model, env)
    }

    func selectedText(_ model: PanelModel) -> String? { model.selectedItem?.text }

    suite("PanelModel") {
        test("lists pinned items first, then recent") {
            let (model, _) = makeModel(recent: ["r1", "r2"], pinned: ["p1"])
            expectEqual(model.visible.map(\.text), ["p1", "r1", "r2"])
        }

        test("reset clears the search, selects the first item and requests focus") {
            let (model, _) = makeModel(recent: ["a", "b"])
            model.query = "b"
            let token = model.focusToken
            model.reset()
            expectEqual(model.query, "")
            expectEqual(selectedText(model), "a")
            expectEqual(model.focusToken, token + 1)
        }

        test("search is case-insensitive and covers both sections") {
            let (model, _) = makeModel(recent: ["Hello World", "goodbye"], pinned: ["HELLO pinned"])
            model.query = "hello"
            expectEqual(model.visible.map(\.text), ["HELLO pinned", "Hello World"])
        }

        test("whitespace-only search shows everything") {
            let (model, _) = makeModel(recent: ["a", "b"])
            model.query = "   "
            expectEqual(model.visible.count, 2)
        }

        test("search with no matches") {
            let (model, _) = makeModel(recent: ["a"])
            model.query = "zzz"
            expect(model.visible.isEmpty)
            expect(model.selection == nil)
            model.move(1) // must not crash
            expect(model.selectedItem == nil)
        }

        test("changing the search selects the first result") {
            let (model, _) = makeModel(recent: ["apple", "banana", "avocado"])
            model.move(1)
            model.query = "av"
            expectEqual(selectedText(model), "avocado")
        }

        test("arrow navigation clamps at both ends") {
            let (model, _) = makeModel(recent: ["a", "b", "c"])
            model.move(-1)
            expectEqual(selectedText(model), "a")
            model.move(1)
            model.move(1)
            model.move(1)
            expectEqual(selectedText(model), "c")
        }

        test("navigation crosses from pinned into recent") {
            let (model, _) = makeModel(recent: ["r"], pinned: ["p"])
            expectEqual(selectedText(model), "p")
            model.move(1)
            expectEqual(selectedText(model), "r")
        }

        test("moveToTop / moveToBottom") {
            let (model, _) = makeModel(recent: ["a", "b", "c"])
            model.moveToBottom()
            expectEqual(selectedText(model), "c")
            model.moveToTop()
            expectEqual(selectedText(model), "a")
        }

        test("empty history: nothing selected, navigation is safe") {
            let (model, _) = makeModel(recent: [])
            model.move(1)
            model.moveToBottom()
            expect(model.selection == nil)
        }

        test("deleting the selected item selects the next one") {
            let (model, _) = makeModel(recent: ["a", "b", "c"])
            model.move(1)
            model.delete(model.selection!)
            expectEqual(selectedText(model), "c")
            expectEqual(model.visible.map(\.text), ["a", "c"])
        }

        test("deleting the last item selects the new last one") {
            let (model, _) = makeModel(recent: ["a", "b", "c"])
            model.moveToBottom()
            model.delete(model.selection!)
            expectEqual(selectedText(model), "b")
        }

        test("deleting the only item clears the selection") {
            let (model, _) = makeModel(recent: ["a"])
            model.delete(model.selection!)
            expect(model.selection == nil)
        }

        test("deleting another item keeps the selection") {
            let (model, _) = makeModel(recent: ["a", "b", "c"])
            model.moveToBottom()
            model.delete(model.visible[0].id)
            expectEqual(selectedText(model), "c")
        }

        test("deleting within search results keeps the selection in the results") {
            let (model, _) = makeModel(recent: ["x1", "y", "x2", "x3"])
            model.query = "x"
            model.delete(model.selection!)
            expectEqual(selectedText(model), "x2")
        }

        test("pinning the selected item keeps it selected") {
            let (model, _) = makeModel(recent: ["a", "b"])
            model.move(1)
            let id = model.selection!
            model.togglePin(id)
            expectEqual(model.selection, id)
            expectEqual(model.visible.first?.id, id, "now at the top, in Pinned")
        }

        test("clearHistory with a recent item selected moves the selection to a pinned one") {
            let (model, _) = makeModel(recent: ["r1", "r2"], pinned: ["p"])
            model.moveToBottom()
            model.clearHistory()
            expectEqual(selectedText(model), "p")
        }

        test("hover selects only when the mouse actually moves") {
            let (model, _) = makeModel(recent: ["a", "b", "c"])
            model.reset(mouseLocation: CGPoint(x: 10, y: 10))
            let c = model.visible[2].id
            // A row scrolled under a still cursor reports hover; ignore it.
            model.hover(c, mouseLocation: CGPoint(x: 10, y: 10))
            expectEqual(selectedText(model), "a")
            // Real mouse movement selects.
            model.hover(c, mouseLocation: CGPoint(x: 10, y: 30))
            expectEqual(selectedText(model), "c")
            // Keyboard navigation then wins until the mouse moves again.
            model.move(-1)
            model.hover(c, mouseLocation: CGPoint(x: 10, y: 30))
            expectEqual(selectedText(model), "b")
        }

        test("new clips arriving while open don't move the selection") {
            let (model, env) = makeModel(recent: ["a", "b"])
            _ = env
            model.move(1)
            model.store.add("new")
            expectEqual(selectedText(model), "b")
        }

        test("filtering 1,000 items is fast") {
            let env = TestEnv()
            let store = env.makeStore()
            store.maxHistory = 1000
            (1...1000).forEach { store.add("item number \($0) " + String(repeating: "lorem ipsum ", count: 20)) }
            let model = PanelModel(store: store)
            model.query = "number 99"
            let time = measure { _ = model.visible }
            expect(time < 0.05, "took \(time)s")
            expectEqual(model.visible.count, 11) // 99 and 990–999
            store.flush()
        }
    }
}
