import AppKit
import SwiftUI

/// A floating panel that can take keyboard focus without activating the app,
/// so the app you were typing in stays frontmost (like Spotlight / Win+V).
final class ClipPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { standardWindowButton($0)?.isHidden = true }
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

public final class PanelController {
    private let store: ClipboardStore
    private let model: PanelModel
    private let panel = ClipPanel()
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var lastHidden = Date.distantPast
    private var promptedForAccessibility = false

    public init(store: ClipboardStore) {
        self.store = store
        model = PanelModel(store: store)

        let root = ClipboardView(store: store, model: model, actions: .init(
            paste: { [weak self] item in self?.paste(item) },
            copy: { [weak self] item in self?.paste(item, copyOnly: true) },
            togglePin: { [weak self] item in self?.model.togglePin(item.id) },
            delete: { [weak self] item in self?.model.delete(item.id) },
            clearHistory: { [weak self] in self?.model.clearHistory() }
        ))

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        let hosting = NSHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.contentView = effect
        panel.onResignKey = { [weak self] in self?.hide() }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    public var isVisible: Bool { panel.isVisible }

    public func toggle(below anchor: NSRect? = nil) {
        if isVisible {
            hide()
        } else if Date().timeIntervalSince(lastHidden) > 0.3 {
            // Clicking the menu bar icon while the panel is open first hides it (it loses key status),
            // then delivers the click; without this check that click would reopen it.
            show(below: anchor)
        }
    }

    /// Shows the panel near the mouse cursor, or below `anchor` (e.g. the menu bar icon).
    public func show(below anchor: NSRect? = nil) {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }

        let mouse = NSEvent.mouseLocation
        model.reset(mouseLocation: mouse)

        let point = anchor.map { NSPoint(x: $0.midX, y: $0.midY) } ?? mouse
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        if let screen {
            panel.setFrameOrigin(PanelPlacement.origin(size: panel.frame.size, anchor: anchor,
                                                       mouse: mouse, visibleFrame: screen.visibleFrame))
        }
        panel.makeKeyAndOrderFront(nil)
    }

    public func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        lastHidden = Date()
    }

    /// Copies the item and, unless `copyOnly`, pastes it into the app you were using.
    private func paste(_ item: ClipItem, copyOnly: Bool = false) {
        Paster.copy(item.text)
        hide()
        guard !copyOnly else { return }
        guard Paster.hasAccessibility else {
            if !promptedForAccessibility {
                promptedForAccessibility = true
                Paster.requestAccessibility()
            }
            return
        }
        // Normally the panel never activates ClipShelf, but if something did (e.g. an alert),
        // hand focus back so ⌘V lands in the right app.
        var delay = 0.05
        if NSApp.isActive, let previousApp {
            previousApp.activate()
            delay = 0.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Paster.sendPasteKeystroke()
        }
    }

    /// Returns true if the key was handled.
    private func handleKey(_ event: NSEvent) -> Bool {
        let editor = panel.firstResponder as? NSTextView
        guard let command = PanelCommand.from(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            characters: event.charactersIgnoringModifiers,
            queryIsEmpty: model.query.isEmpty,
            searchHasSelection: (editor?.selectedRange().length ?? 0) > 0
        ) else { return false }

        switch command {
        case .close: hide()
        case .clearSearch: model.query = ""
        case .moveUp: model.move(-1)
        case .moveDown: model.move(1)
        case .moveToTop: model.moveToTop()
        case .moveToBottom: model.moveToBottom()
        case .paste: if let item = model.selectedItem { paste(item) }
        case .copy: if let item = model.selectedItem { paste(item, copyOnly: true) }
        case .togglePin: if let item = model.selectedItem { model.togglePin(item.id) }
        case .delete: if let item = model.selectedItem { model.delete(item.id) }
        case .pasteItem(let index):
            let items = model.visible
            if items.indices.contains(index) { paste(items[index]) }
        }
        return true
    }
}
