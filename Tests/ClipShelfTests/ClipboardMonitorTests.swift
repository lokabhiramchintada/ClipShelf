import AppKit
@testable import ClipShelfCore

func clipboardMonitorTests() {
    /// A private pasteboard, so tests never touch the real clipboard.
    func withPasteboard(_ body: (NSPasteboard, TestEnv) throws -> Void) rethrows {
        let pb = NSPasteboard(name: .init("ClipShelfTests-\(UUID().uuidString)"))
        defer { pb.releaseGlobally() }
        try body(pb, TestEnv())
    }

    suite("ClipboardMonitor") {
        test("records what's on the clipboard at launch") {
            withPasteboard { pb, env in
                Paster.copy("already there", to: pb)
                var seen: [String] = []
                let monitor = ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { seen.append($0) }
                monitor.poll()
                expectEqual(seen, ["already there"])
            }
        }

        test("reports each change exactly once") {
            withPasteboard { pb, env in
                var seen: [String] = []
                let monitor = ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { seen.append($0) }
                monitor.poll()
                Paster.copy("one", to: pb)
                expect(monitor.poll())
                expect(!monitor.poll(), "no change, nothing reported")
                Paster.copy("two", to: pb)
                monitor.poll()
                Paster.copy("two", to: pb) // same text copied again is still a new copy
                monitor.poll()
                expectEqual(seen, ["one", "two", "two"])
            }
        }

        test("ignores content marked concealed or transient (password managers)") {
            withPasteboard { pb, env in
                var seen: [String] = []
                let monitor = ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { seen.append($0) }
                for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
                               "com.agilebits.onepassword"] {
                    pb.clearContents()
                    pb.declareTypes([.string, .init(marker)], owner: nil)
                    pb.setString("secret", forType: .string)
                    pb.setString("", forType: .init(marker))
                    expect(!monitor.poll(), "\(marker) should be ignored")
                }
                expect(seen.isEmpty, "recorded \(seen)")
            }
        }

        test("ignores non-text content") {
            withPasteboard { pb, env in
                var seen: [String] = []
                let monitor = ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { seen.append($0) }
                pb.clearContents()
                pb.setData(Data([0x89, 0x50, 0x4E, 0x47]), forType: .png)
                expect(!monitor.poll())
                expect(seen.isEmpty)
            }
        }

        test("records nothing while paused, including what was copied during the pause") {
            withPasteboard { pb, env in
                var seen: [String] = []
                let monitor = ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { seen.append($0) }
                monitor.isPaused = true
                Paster.copy("private", to: pb)
                expect(!monitor.poll())
                monitor.isPaused = false
                expect(!monitor.poll(), "the copy made while paused stays unrecorded")
                Paster.copy("public", to: pb)
                monitor.poll()
                expectEqual(seen, ["public"])
            }
        }

        test("paused state persists") {
            let env = TestEnv()
            let pb = NSPasteboard(name: .init("ClipShelfTests-\(UUID().uuidString)"))
            defer { pb.releaseGlobally() }
            ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { _ in }.isPaused = true
            expect(ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { _ in }.isPaused)
        }

        test("end to end: copy → monitor → store, and pasting an item back moves it to the top") {
            withPasteboard { pb, env in
                let store = env.makeStore()
                let monitor = ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { store.add($0) }
                for text in ["alpha", "beta", "gamma"] {
                    Paster.copy(text, to: pb)
                    monitor.poll()
                }
                expectEqual(store.items.map(\.text), ["gamma", "beta", "alpha"])
                Paster.copy(store.items[2].text, to: pb) // what pasting "alpha" from the panel does
                monitor.poll()
                expectEqual(store.items.map(\.text), ["alpha", "gamma", "beta"])
                expectEqual(pb.string(forType: .string), "alpha")
            }
        }

        test("start() polls on a timer") {
            withPasteboard { pb, env in
                var seen: [String] = []
                let monitor = ClipboardMonitor(pasteboard: pb, defaults: env.defaults) { seen.append($0) }
                monitor.start()
                defer { monitor.stop() }
                Paster.copy("from timer", to: pb)
                RunLoop.main.run(until: Date().addingTimeInterval(1.0))
                expectEqual(seen, ["from timer"])
            }
        }
    }
}
