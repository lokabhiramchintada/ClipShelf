import Foundation

public struct ClipItem: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var text: String
    public var createdAt: Date
    public var lastUsedAt: Date
    public var pinned: Bool

    public init(text: String, date: Date = Date()) {
        id = UUID()
        self.text = text
        createdAt = date
        lastUsedAt = date
        pinned = false
    }

    static let previewLength = 400

    /// Short, render-friendly version of the text for the list.
    /// Only looks at the start of the text so huge clips stay cheap to render.
    public var preview: String {
        let start = text.firstIndex { !$0.isWhitespace } ?? text.endIndex
        let head = text[start...].prefix(Self.previewLength)
        let truncated = text[head.endIndex...].contains { !$0.isWhitespace }
        let trimmed = String(head).trimmingCharacters(in: .whitespacesAndNewlines)
        return truncated ? trimmed + "…" : trimmed
    }

    /// Number of lines, ignoring leading/trailing blank lines.
    public var lineCount: Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).reduce(1) { $1.isNewline ? $0 + 1 : $0 }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    /// e.g. "Just now · 3 lines · 120 chars"
    public func metadata(relativeTo now: Date = Date()) -> String {
        let when = now.timeIntervalSince(lastUsedAt) < 10
            ? "Just now"
            : Self.relativeFormatter.localizedString(for: lastUsedAt, relativeTo: now)
        var parts = [when]
        let lines = lineCount
        if lines > 1 { parts.append("\(lines.formatted()) lines") }
        let chars = text.count
        parts.append(chars == 1 ? "1 char" : "\(chars.formatted()) chars")
        return parts.joined(separator: " · ")
    }
}
