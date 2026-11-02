import Foundation
@testable import ClipShelfCore

func clipItemTests() {
    suite("ClipItem") {
        test("preview trims surrounding whitespace") {
            expectEqual(ClipItem(text: "  \n\thello world \n ").preview, "hello world")
        }

        test("preview keeps short text intact") {
            expectEqual(ClipItem(text: "line 1\nline 2").preview, "line 1\nline 2")
        }

        test("preview truncates long text with an ellipsis") {
            let preview = ClipItem(text: String(repeating: "a", count: 1000)).preview
            expectEqual(preview.count, ClipItem.previewLength + 1)
            expect(preview.hasSuffix("…"))
        }

        test("preview has no ellipsis when only whitespace was cut off") {
            let text = String(repeating: "a", count: ClipItem.previewLength) + String(repeating: " ", count: 50)
            expect(!ClipItem(text: text).preview.hasSuffix("…"))
        }

        test("preview finds content after a long run of leading whitespace") {
            let text = String(repeating: "\n", count: 2000) + "content"
            expectEqual(ClipItem(text: text).preview, "content")
        }

        test("preview handles emoji and combined characters") {
            expectEqual(ClipItem(text: " 👨‍👩‍👧 café ").preview, "👨‍👩‍👧 café")
        }

        test("preview of a 1 MB clip is fast") {
            let item = ClipItem(text: String(repeating: "word ", count: 200_000))
            let time = measure { _ = item.preview }
            expect(time < 0.05, "took \(time)s")
        }

        test("lineCount") {
            expectEqual(ClipItem(text: "one").lineCount, 1)
            expectEqual(ClipItem(text: "a\nb\nc").lineCount, 3)
            expectEqual(ClipItem(text: "a\n\nb").lineCount, 3, "blank lines inside count")
            expectEqual(ClipItem(text: "\n\na\nb\n\n").lineCount, 2, "leading/trailing blank lines don't")
            expectEqual(ClipItem(text: "a\r\nb").lineCount, 2, "CRLF is one line break")
        }

        test("metadata: just now, singular/plural, line count") {
            let now = Date()
            expectEqual(ClipItem(text: "x", date: now).metadata(relativeTo: now), "Just now · 1 char")
            expectEqual(ClipItem(text: "ab", date: now).metadata(relativeTo: now), "Just now · 2 chars")
            expectEqual(ClipItem(text: "a\nb", date: now).metadata(relativeTo: now), "Just now · 2 lines · 3 chars")
        }

        test("metadata: older items show a relative time, never a future one") {
            let now = Date()
            let meta = ClipItem(text: "x", date: now.addingTimeInterval(-3600)).metadata(relativeTo: now)
            expect(!meta.hasPrefix("Just now"), meta)
            expect(!meta.hasPrefix("in "), meta)
            // A clock skew of a few seconds into the future still reads "Just now".
            expectEqual(ClipItem(text: "x", date: now.addingTimeInterval(2)).metadata(relativeTo: now), "Just now · 1 char")
        }

        test("Codable round trip") {
            var item = ClipItem(text: "héllo\r\n🌍")
            item.pinned = true
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(ClipItem.self, from: encoder.encode(item))
            expectEqual(decoded.id, item.id)
            expectEqual(decoded.text, item.text)
            expectEqual(decoded.pinned, true)
        }
    }
}
