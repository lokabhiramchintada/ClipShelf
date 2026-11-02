import AppKit

_ = NSApplication.shared

clipItemTests()
clipboardStoreTests()
clipboardMonitorTests()
panelModelTests()
panelCommandTests()
placementTests()
hotKeyTests()
viewTests()
TestEnv.cleanUpAll()

let total = TestRunner.passed + TestRunner.failed
print("\n\(TestRunner.failed == 0 ? "✅" : "❌") \(TestRunner.passed)/\(total) tests passed")
exit(TestRunner.failed == 0 ? 0 : 1)
