import Foundation
@testable import ClipShelfCore

func clipboardStoreTests() {
    suite("ClipboardStore") {
        test("starts empty when there is no history file") {
            let env = TestEnv()
            expect(env.makeStore().items.isEmpty)
        }

        test("add inserts newest first") {
            let store = TestEnv().makeStore()
            store.add("one")
            store.add("two")
            expectEqual(store.items.map(\.text), ["two", "one"])
        }

        test("ignores empty and whitespace-only text") {
            let store = TestEnv().makeStore()
            ["", " ", "\n\t \r\n"].forEach { store.add($0) }
            expect(store.items.isEmpty)
        }

        test("keeps surrounding whitespace in the stored text") {
            let store = TestEnv().makeStore()
            store.add("  indented\n")
            expectEqual(store.items.first?.text, "  indented\n")
        }

        test("ignores text over the size limit, accepts text at it") {
            let store = TestEnv().makeStore()
            store.add(String(repeating: "a", count: ClipboardStore.maxItemLength + 1))
            expect(store.items.isEmpty)
            store.add(String(repeating: "a", count: ClipboardStore.maxItemLength))
            expectEqual(store.items.count, 1)
        }

        test("re-copying moves the item to the top without duplicating it") {
            let store = TestEnv().makeStore()
            let early = Date(timeIntervalSince1970: 1000)
            store.add("a", date: early)
            store.add("b", date: early)
            let id = store.items.last!.id
            store.add("a", date: Date(timeIntervalSince1970: 2000))
            expectEqual(store.items.map(\.text), ["a", "b"])
            expectEqual(store.items.first?.id, id, "keeps the same item")
            expectEqual(store.items.first?.lastUsedAt, Date(timeIntervalSince1970: 2000))
            expectEqual(store.items.first?.createdAt, early)
        }

        test("texts differing only in whitespace are different items") {
            let store = TestEnv().makeStore()
            store.add("a")
            store.add("a ")
            expectEqual(store.items.count, 2)
        }

        test("re-copying a pinned item keeps its position") {
            let store = TestEnv().makeStore()
            store.add("pinned")
            store.add("other")
            let pinnedID = store.items.first { $0.text == "pinned" }!.id
            store.togglePin(pinnedID)
            store.add("pinned", date: Date(timeIntervalSince1970: 5000))
            expectEqual(store.items.map(\.text), ["other", "pinned"])
            expectEqual(store.pinned.first?.lastUsedAt, Date(timeIntervalSince1970: 5000))
        }

        test("togglePin moves items between pinned and recent") {
            let store = TestEnv().makeStore()
            store.add("a")
            store.add("b")
            let a = store.items.first { $0.text == "a" }!.id
            store.togglePin(a)
            expectEqual(store.pinned.map(\.text), ["a"])
            expectEqual(store.recent.map(\.text), ["b"])
            store.togglePin(a)
            expect(store.pinned.isEmpty)
            expectEqual(store.recent.count, 2)
        }

        test("togglePin/delete with an unknown id do nothing") {
            let store = TestEnv().makeStore()
            store.add("a")
            store.togglePin(UUID())
            store.delete(UUID())
            expectEqual(store.items.map(\.text), ["a"])
            expect(store.pinned.isEmpty)
        }

        test("history is trimmed to maxHistory, dropping the oldest") {
            let env = TestEnv()
            let store = env.makeStore()
            store.maxHistory = 3
            (1...5).forEach { store.add("item \($0)") }
            expectEqual(store.items.map(\.text), ["item 5", "item 4", "item 3"])
        }

        test("pinned items are never trimmed") {
            let store = TestEnv().makeStore()
            store.add("keep 1")
            store.add("keep 2")
            store.items.forEach { store.togglePin($0.id) }
            store.maxHistory = 1
            (1...10).forEach { store.add("x\($0)") }
            expectEqual(store.pinned.count, 2)
            expectEqual(store.recent.map(\.text), ["x10"])
        }

        test("unpinning an item past the limit trims the oldest") {
            let store = TestEnv().makeStore()
            store.maxHistory = 2
            store.add("old pin")
            store.togglePin(store.items[0].id)
            store.add("a")
            store.add("b")
            store.togglePin(store.pinned[0].id)
            expectEqual(store.recent.count, 2)
        }

        test("maxHistory defaults to 200, persists, and is at least 1") {
            let env = TestEnv()
            let store = env.makeStore()
            expectEqual(store.maxHistory, 200)
            store.maxHistory = 50
            expectEqual(env.makeStore().maxHistory, 50)
            store.maxHistory = 0
            expectEqual(store.maxHistory, 1)
        }

        test("lowering maxHistory trims immediately") {
            let store = TestEnv().makeStore()
            (1...10).forEach { store.add("\($0)") }
            store.maxHistory = 4
            expectEqual(store.items.count, 4)
        }

        test("delete removes the item") {
            let store = TestEnv().makeStore()
            store.add("a")
            store.add("b")
            store.delete(store.items[0].id)
            expectEqual(store.items.map(\.text), ["a"])
        }

        test("clearHistory keeps pinned items") {
            let store = TestEnv().makeStore()
            store.add("pin")
            store.togglePin(store.items[0].id)
            store.add("a")
            store.add("b")
            store.clearHistory()
            expectEqual(store.items.map(\.text), ["pin"])
        }

        test("history persists across launches") {
            let env = TestEnv()
            let store = env.makeStore()
            store.add("first")
            store.add("second 🎉\r\nwith lines")
            store.togglePin(store.items.last!.id)
            store.flush()

            let reloaded = env.makeStore()
            expectEqual(reloaded.items.map(\.id), store.items.map(\.id))
            expectEqual(reloaded.items.map(\.text), store.items.map(\.text))
            expectEqual(reloaded.items.map(\.pinned), [false, true])
        }

        test("rapid writes land on disk in order") {
            let env = TestEnv()
            let store = env.makeStore()
            (1...300).forEach { store.add("item \($0)") }
            store.togglePin(store.items[5].id)
            store.delete(store.items[0].id)
            store.flush()
            let reloaded = env.makeStore().items
            expectEqual(reloaded.map(\.id), store.items.map(\.id))
            expectEqual(reloaded.map(\.text), store.items.map(\.text))
            expectEqual(reloaded.map(\.pinned), store.items.map(\.pinned))
        }

        test("dates survive a save/load to the millisecond") {
            let env = TestEnv()
            let store = env.makeStore()
            let date = Date(timeIntervalSince1970: 1_700_000_000.123)
            store.add("a", date: date)
            store.flush()
            let loaded = env.makeStore().items[0]
            expect(abs(loaded.lastUsedAt.timeIntervalSince(date)) < 0.001, "\(loaded.lastUsedAt.timeIntervalSince1970)")
            expect(abs(loaded.createdAt.timeIntervalSince(date)) < 0.001)
        }

        test("dates are saved as standard ISO 8601 in UTC") {
            let env = TestEnv()
            let store = env.makeStore()
            store.add("a", date: Date(timeIntervalSince1970: 1_700_000_000.5))
            store.flush()
            let json = try String(contentsOf: env.historyURL, encoding: .utf8)
            expect(json.contains("\"2023-11-14T22:13:20.500Z\""), json)
        }

        test("reads history files written without fractional seconds") {
            let env = TestEnv()
            let json = """
            [{"text":"old","id":"3B5021D6-7E8E-4190-8B24-538DB5867A3A","createdAt":"2026-11-02T10:43:00Z",
              "lastUsedAt":"2026-11-02T10:43:00Z","pinned":true}]
            """
            try Data(json.utf8).write(to: env.historyURL)
            let store = env.makeStore()
            expectEqual(store.items.map(\.text), ["old"])
            expectEqual(store.items.first?.pinned, true)
        }

        test("creates the history directory if it's missing") {
            let env = TestEnv()
            let url = env.dir.appendingPathComponent("nested/deeper/history.json")
            let store = env.makeStore(fileURL: url)
            store.add("hello")
            store.flush()
            expect(FileManager.default.fileExists(atPath: url.path))
            expectEqual(env.makeStore(fileURL: url).items.map(\.text), ["hello"])
        }

        test("a corrupt history file is backed up, not overwritten") {
            let env = TestEnv()
            try Data("{not json".utf8).write(to: env.historyURL)
            let store = env.makeStore()
            expect(store.items.isEmpty)
            store.add("new")
            store.flush()

            let files = try FileManager.default.contentsOfDirectory(atPath: env.dir.path)
            let backups = files.filter { $0.contains("corrupt") }
            expectEqual(backups.count, 1, "files: \(files)")
            if let backup = backups.first {
                let content = try String(contentsOf: env.dir.appendingPathComponent(backup), encoding: .utf8)
                expectEqual(content, "{not json")
            }
            expectEqual(env.makeStore().items.map(\.text), ["new"])
        }

        test("loading a file with more items than maxHistory trims it") {
            let env = TestEnv()
            let store = env.makeStore()
            (1...10).forEach { store.add("\($0)") }
            store.flush()
            env.defaults.set(3, forKey: "maxHistory")
            expectEqual(env.makeStore().items.count, 3)
        }

        test("adding to a full history stays fast") {
            let store = TestEnv().makeStore()
            store.maxHistory = 1000
            (1...1000).forEach { store.add("item \($0) " + String(repeating: "x", count: 200)) }
            let time = measure { (1...100).forEach { store.add("new \($0)") } }
            expect(time < 0.5, "100 adds took \(time)s")
            store.flush()
        }
    }
}
