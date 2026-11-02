import AppKit
import ApplicationServices

public enum Paster {
    /// Simulating ⌘V requires Accessibility permission.
    public static var hasAccessibility: Bool { AXIsProcessTrusted() }

    public static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    public static func copy(_ text: String, to pb: NSPasteboard = .general) {
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// Sends ⌘V to whichever app is frontmost.
    public static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
