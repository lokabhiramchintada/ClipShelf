import Foundation
@testable import ClipShelfCore

// A tiny test harness. The Command Line Tools ship neither XCTest nor swift-testing,
// so the suite is a plain executable that exits non-zero on failure.

enum TestRunner {
    static var passed = 0
    static var failed = 0
    static var currentFailures: [String] = []
}

func suite(_ name: String, _ body: () -> Void) {
    print("\n\(name)")
    body()
}

func test(_ name: String, _ body: () throws -> Void) {
    TestRunner.currentFailures = []
    do {
        try body()
    } catch {
        TestRunner.currentFailures.append("threw \(error)")
    }
    if TestRunner.currentFailures.isEmpty {
        TestRunner.passed += 1
        print("  ✓ \(name)")
    } else {
        TestRunner.failed += 1
        print("  ✗ \(name)")
        TestRunner.currentFailures.forEach { print("      \($0)") }
    }
}

func expect(_ condition: Bool, _ message: @autoclosure () -> String = "expectation failed",
            file: StaticString = #fileID, line: UInt = #line) {
    if !condition { TestRunner.currentFailures.append("\(file):\(line): \(message())") }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: @autoclosure () -> String = "",
                               file: StaticString = #fileID, line: UInt = #line) {
    if actual != expected {
        let note = message()
        TestRunner.currentFailures.append(
            "\(file):\(line): expected \(short(expected)), got \(short(actual))\(note.isEmpty ? "" : " — \(note)")")
    }
}

private func short(_ value: Any) -> String {
    let s = String(describing: value)
    return s.count > 300 ? s.prefix(300) + "…" : s
}

/// An isolated temp directory + UserDefaults suite, so tests never touch real user data.
/// Everything is removed by `TestEnv.cleanUpAll()` at the end of the run (not earlier,
/// since stores write to disk in the background).
final class TestEnv {
    let dir: URL
    let defaults: UserDefaults
    private let suiteName: String
    private var stores: [ClipboardStore] = []
    private static var all: [TestEnv] = []

    init() {
        suiteName = "ClipShelfTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(suiteName, isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        TestEnv.all.append(self)
    }

    var historyURL: URL { dir.appendingPathComponent("history.json") }

    func makeStore(fileURL: URL? = nil) -> ClipboardStore {
        let store = ClipboardStore(fileURL: fileURL ?? historyURL, defaults: defaults)
        stores.append(store)
        return store
    }

    static func cleanUpAll() {
        for env in all {
            env.stores.forEach { $0.flush() }
            env.defaults.removePersistentDomain(forName: env.suiteName)
            try? FileManager.default.removeItem(at: env.dir)
        }
        all = []
    }
}

/// Measures how long `body` takes, in seconds.
func measure(_ body: () -> Void) -> TimeInterval {
    let start = Date()
    body()
    return Date().timeIntervalSince(start)
}
