import AppKit
import ClipShelfCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipboardStore()
    private var monitor: ClipboardMonitor!
    private var panel: PanelController!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController(store: store)
        monitor = ClipboardMonitor { [weak self] text in self?.store.add(text) }
        monitor.start()
        setUpStatusItem()
        registerHotKey(showErrors: true)

        // Ask for Accessibility (needed for auto-paste) on first launch only; after that it's in the menu.
        if !Paster.hasAccessibility && !UserDefaults.standard.bool(forKey: "didPromptAccessibility") {
            UserDefaults.standard.set(true, forKey: "didPromptAccessibility")
            Paster.requestAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
    }

    private func registerHotKey(showErrors: Bool) {
        let preset = HotKeyPreset.current()
        hotKey = nil // unregister the old shortcut first
        hotKey = HotKey(keyCode: preset.keyCode, modifiers: preset.modifiers) { [weak self] in
            self?.panel.toggle()
        }
        if showErrors, hotKey?.isRegistered == false {
            let alert = NSAlert()
            alert.messageText = "\(preset.title) is already in use"
            alert.informativeText = "Another app has claimed this shortcut. Right-click the ClipShelf menu bar icon and pick a different one under Shortcut."
            NSApp.activate()
            alert.runModal()
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipShelf")
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Left click opens the clipboard panel; right click (or ⌃-click) shows the settings menu.
    @objc private func statusItemClicked() {
        guard let button = statusItem.button, let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            panel.hide()
            statusItem.menu = buildMenu()
            button.performClick(nil)
        } else if let window = button.window {
            panel.toggle(below: window.convertToScreen(button.convert(button.bounds, to: nil)))
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil // so the next left click goes to statusItemClicked again
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let current = HotKeyPreset.current()

        menu.addItem(item("Open Clipboard  (\(current.title))", #selector(openPanel)))
        menu.addItem(.separator())

        let pause = item("Pause Recording", #selector(togglePause))
        pause.state = monitor.isPaused ? .on : .off
        menu.addItem(pause)

        let hotKeyMenu = NSMenu()
        for preset in HotKeyPreset.allCases {
            let mi = item(preset.title, #selector(selectHotKey(_:)))
            mi.representedObject = preset.rawValue
            mi.state = preset == current ? .on : .off
            hotKeyMenu.addItem(mi)
        }
        let hotKeyItem = NSMenuItem(title: "Shortcut", action: nil, keyEquivalent: "")
        hotKeyItem.submenu = hotKeyMenu
        menu.addItem(hotKeyItem)

        let historyMenu = NSMenu()
        for size in ClipboardStore.historySizes {
            let mi = item("\(size) items", #selector(selectHistorySize(_:)))
            mi.tag = size
            mi.state = size == store.maxHistory ? .on : .off
            historyMenu.addItem(mi)
        }
        let historyItem = NSMenuItem(title: "History Size", action: nil, keyEquivalent: "")
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)

        let login = item("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        if !Paster.hasAccessibility {
            menu.addItem(item("Enable Auto-Paste (Accessibility)…", #selector(openAccessibilitySettings)))
        }

        menu.addItem(.separator())
        menu.addItem(item("Clear History (keeps pinned)", #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(item("Quit ClipShelf", #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = self
        return mi
    }

    @objc private func openPanel() { panel.show() }
    @objc private func togglePause() { monitor.isPaused.toggle() }
    @objc private func clearHistory() { store.clearHistory() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func selectHotKey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let preset = HotKeyPreset(rawValue: raw) else { return }
        HotKeyPreset.setCurrent(preset)
        registerHotKey(showErrors: true)
    }

    @objc private func selectHistorySize(_ sender: NSMenuItem) {
        store.maxHistory = sender.tag
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nMove ClipShelf.app to /Applications and try again."
            NSApp.activate()
            alert.runModal()
        }
    }

    @objc private func openAccessibilitySettings() {
        Paster.requestAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
