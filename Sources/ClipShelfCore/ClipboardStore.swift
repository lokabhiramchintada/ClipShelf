import Foundation

/// Holds clipboard history + pinned items and persists them to disk.
public final class ClipboardStore: ObservableObject {
    @Published public private(set) var items: [ClipItem] = []

    /// Clips longer than this (in UTF-16 code units) are ignored to keep the history file small.
    public static let maxItemLength = 1_000_000
    public static let historySizes = [50, 100, 200, 500, 1000]
    public static let defaultMaxHistory = 200

    public static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipShelf", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    public let fileURL: URL
    private let defaults: UserDefaults
    private let saveQueue = DispatchQueue(label: "ClipShelf.save", qos: .utility)

    public init(fileURL: URL = ClipboardStore.defaultFileURL, defaults: UserDefaults = .standard) {
        self.fileURL = fileURL
        self.defaults = defaults
        load()
    }

    /// Max number of unpinned items kept. Pinned items are never trimmed.
    public var maxHistory: Int {
        get {
            let value = defaults.integer(forKey: "maxHistory")
            return value > 0 ? value : Self.defaultMaxHistory
        }
        set {
            defaults.set(max(1, newValue), forKey: "maxHistory")
            trim()
            save()
        }
    }

    public var pinned: [ClipItem] { items.filter(\.pinned) }
    public var recent: [ClipItem] { items.filter { !$0.pinned } }

    /// Records newly copied text. Re-copying existing text moves it to the top
    /// (pinned items keep their position).
    public func add(_ text: String, date: Date = Date()) {
        guard text.utf16.count <= Self.maxItemLength,
              text.contains(where: { !$0.isWhitespace }) else { return }

        if let idx = items.firstIndex(where: { $0.text == text }) {
            if items[idx].pinned {
                items[idx].lastUsedAt = date
            } else {
                var item = items.remove(at: idx)
                item.lastUsedAt = date
                items.insert(item, at: 0)
            }
        } else {
            items.insert(ClipItem(text: text, date: date), at: 0)
        }
        trim()
        save()
    }

    public func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        trim() // unpinning can push history over the limit
        save()
    }

    public func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// Removes all unpinned items.
    public func clearHistory() {
        items.removeAll { !$0.pinned }
        save()
    }

    /// Blocks until pending writes have reached disk.
    public func flush() {
        saveQueue.sync {}
    }

    private func trim() {
        let limit = maxHistory
        var unpinnedSeen = 0
        items.removeAll { item in
            guard !item.pinned else { return false }
            unpinnedSeen += 1
            return unpinnedSeen > limit
        }
    }

    // Dates are ISO 8601 in UTC with fractional seconds (2026-11-02T10:43:00.123Z);
    // files written without fractional seconds are still readable.
    static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(string, strategy: dateStyle) {
                return date
            }
            if let date = try? Date(string, strategy: .iso8601) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Invalid date: \(string)"))
        }
        return decoder
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return } // no history yet
        let decoder = Self.makeDecoder()
        do {
            items = try decoder.decode([ClipItem].self, from: data)
            trim()
        } catch {
            // Keep the unreadable file rather than silently overwriting it (and the pins in it) on the next save.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            NSLog("ClipShelf: could not read \(fileURL.path) (\(error)); moved it to \(backup.lastPathComponent)")
        }
    }

    private func save() {
        let snapshot = items
        let url = fileURL
        // A serial queue keeps writes in order, so an older snapshot never overwrites a newer one.
        saveQueue.async {
            do {
                let data = try Self.makeEncoder().encode(snapshot)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("ClipShelf: failed to save history: \(error)")
            }
        }
    }
}

