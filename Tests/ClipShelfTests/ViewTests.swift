import AppKit
import SwiftUI
@testable import ClipShelfCore

/// Renders the panel offscreen. Checks that it lays out and writes PNGs to build/snapshots
/// for eyeballing changes.
func viewTests() {
    let snapshotDir = URL(fileURLWithPath: "build/snapshots", isDirectory: true)
    try? FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)

    let noActions = ClipActions(paste: { _ in }, copy: { _ in }, togglePin: { _ in },
                                delete: { _ in }, clearHistory: {})

    func render(_ model: PanelModel, name: String, dark: Bool = false) -> NSBitmapImageRep? {
        let view = ClipboardView(store: model.store, model: model, actions: noActions)
            .background(Color(nsColor: .windowBackgroundColor))
        let hosting = NSHostingView(rootView: view)
        hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 480)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2)) // let SwiftUI finish its first pass

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?
            .write(to: snapshotDir.appendingPathComponent("\(name).png"))
        return rep
    }

    /// True if the image has more than one color, i.e. something was drawn.
    func hasContent(_ rep: NSBitmapImageRep) -> Bool {
        let first = rep.colorAt(x: 0, y: 0)
        for x in stride(from: 0, to: rep.pixelsWide, by: 7) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 7) where rep.colorAt(x: x, y: y) != first {
                return true
            }
        }
        return false
    }

    suite("ClipboardView (offscreen render)") {
        let env = TestEnv()
        let store = env.makeStore()
        let base = Date()
        store.add("ssh -i ~/.ssh/id_ed25519 deploy@prod-server.example.com", date: base.addingTimeInterval(-60 * 60 * 26))
        store.togglePin(store.items[0].id)
        store.add("lokabhiram@example.com", date: base.addingTimeInterval(-60 * 60 * 24 * 3))
        store.togglePin(store.items[0].id)
        store.add("func greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}", date: base.addingTimeInterval(-60 * 12))
        store.add("https://github.com/lokabhiramchintada/ClipShelf", date: base.addingTimeInterval(-60 * 3))
        store.add("Meeting notes: ship v1.0 on Friday, write release notes, update the README screenshots.", date: base.addingTimeInterval(-45))
        store.add("The quick brown fox jumps over the lazy dog", date: base)

        test("renders history in light mode") {
            let model = PanelModel(store: store)
            model.reset()
            model.move(2)
            guard let rep = render(model, name: "panel-light") else { return expect(false, "no image") }
            expectEqual(rep.size, NSSize(width: 400, height: 480))
            expect(hasContent(rep))
        }

        test("renders history in dark mode") {
            let model = PanelModel(store: store)
            model.reset()
            guard let rep = render(model, name: "panel-dark", dark: true) else { return expect(false, "no image") }
            expect(hasContent(rep))
        }

        test("renders the empty state") {
            let model = PanelModel(store: TestEnv().makeStore())
            model.reset()
            guard let rep = render(model, name: "panel-empty") else { return expect(false, "no image") }
            expect(hasContent(rep))
        }

        test("renders search with no matches") {
            let model = PanelModel(store: store)
            model.reset()
            model.query = "nothing matches this"
            guard let rep = render(model, name: "panel-no-matches") else { return expect(false, "no image") }
            expect(hasContent(rep))
        }

        test("renders a huge clip without hanging") {
            let big = TestEnv().makeStore()
            big.add(String(repeating: "a very long line of text ", count: 40_000))
            let model = PanelModel(store: big)
            model.reset()
            let time = measure { _ = render(model, name: "panel-huge") }
            expect(time < 2, "took \(time)s")
        }
        store.flush()
    }
}
