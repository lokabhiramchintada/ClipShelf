import Foundation

/// UI state for the panel: search query and keyboard selection.
public final class PanelModel: ObservableObject {
    @Published public var query = "" { didSet { if query != oldValue { selectFirst() } } }
    @Published public var selection: UUID?
    @Published public private(set) var focusToken = 0
    public let store: ClipboardStore
    private var lastHoverLocation: CGPoint?

    public init(store: ClipboardStore) { self.store = store }

    public var pinnedResults: [ClipItem] { filtered(store.pinned) }
    public var recentResults: [ClipItem] { filtered(store.recent) }
    public var visible: [ClipItem] { pinnedResults + recentResults }
    public var selectedItem: ClipItem? { visible.first { $0.id == selection } }

    private func filtered(_ items: [ClipItem]) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    /// Called each time the panel opens. `mouseLocation` is where the cursor is now,
    /// so a cursor that happens to rest over the list doesn't steal the selection.
    public func reset(mouseLocation: CGPoint? = nil) {
        query = ""
        selectFirst()
        lastHoverLocation = mouseLocation
        focusToken += 1
    }

    public func selectFirst() { selection = visible.first?.id }

    public func move(_ delta: Int) {
        let items = visible
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selection } ?? -1
        selection = items[max(0, min(items.count - 1, current + delta))].id
    }

    public func moveToTop() { selection = visible.first?.id }
    public func moveToBottom() { selection = visible.last?.id }

    /// Selects a row the mouse is over, but only if the mouse actually moved. Rows also report
    /// hover when keyboard navigation scrolls them under a still cursor; those are ignored.
    public func hover(_ id: UUID, mouseLocation: CGPoint) {
        guard mouseLocation != lastHoverLocation else { return }
        lastHoverLocation = mouseLocation
        selection = id
    }

    /// Deletes an item, keeping the selection at the same position in the list.
    public func delete(_ id: UUID) {
        let index = visible.firstIndex { $0.id == id }
        store.delete(id)
        guard selection == id || selectedItem == nil else { return }
        let items = visible
        if let index, !items.isEmpty {
            selection = items[min(index, items.count - 1)].id
        } else {
            selectFirst()
        }
    }

    public func togglePin(_ id: UUID) {
        store.togglePin(id)
        if selectedItem == nil { selectFirst() } // e.g. the item was trimmed after unpinning
    }

    public func clearHistory() {
        store.clearHistory()
        if selectedItem == nil { selectFirst() }
    }
}
