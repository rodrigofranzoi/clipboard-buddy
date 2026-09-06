import XCTest
@testable import ClipboardBuddy
import BuddyCore
import BuddyTesting
import AppKit

final class ClipboardStoreTests: XCTestCase {
    @MainActor
    func testSearchMatchesTextAndOCR() {
        let store = ClipboardStore()
        store.items = []
        store.prepend(ClipboardHistoryItem(text: "invoice #42", tags: [.text]))
        store.prepend(ClipboardHistoryItem(
            imageData: Data([0x00]),
            tags: [.image],
            ocrText: "Meeting notes for Sussex"
        ))

        store.query = "invoice"
        XCTAssertEqual(store.filtered.count, 1)
        XCTAssertEqual(store.filtered.first?.text, "invoice #42")

        store.query = "sussex"
        XCTAssertEqual(store.filtered.count, 1)
        XCTAssertTrue(store.filtered.first?.ocrText.lowercased().contains("sussex") ?? false)

        store.query = ""
        XCTAssertEqual(store.filtered.count, 2)
    }

    @MainActor
    func testTagAndPrepend() {
        let store = ClipboardStore()
        let tagged = ContentTagger.tag(text: BuddyFixtures.sampleURL)
        let item = ClipboardHistoryItem(text: BuddyFixtures.sampleURL, tags: Array(tagged.tags), isSensitive: tagged.isSensitive)
        store.prepend(item)
        XCTAssertFalse(store.items.isEmpty)
        XCTAssertTrue(store.items.first?.tags.contains(.url) ?? false)
    }

    @MainActor
    func testFavorite() {
        let store = ClipboardStore()
        store.addFavorite(name: "Email", content: "me@example.com")
        XCTAssertEqual(store.favorites.first?.name, "Email")
        XCTAssertTrue(store.isFavorited(content: "me@example.com"))
        store.toggleFavorite(name: "Email", content: "me@example.com")
        XCTAssertFalse(store.isFavorited(content: "me@example.com"))
        store.toggleFavorite(name: "Email", content: "me@example.com")
        XCTAssertTrue(store.isFavorited(content: "me@example.com"))
    }

    @MainActor
    func testCapturesFilePathsAndRepresentations() {
        let store = ClipboardStore()
        let item = ClipboardHistoryItem(
            text: nil,
            imageData: nil,
            representations: [
                ClipboardRepresentation(type: "public.utf8-plain-text", data: Data("hello".utf8)),
                ClipboardRepresentation(type: "public.file-url", data: Data("file:///tmp/demo.txt".utf8))
            ],
            filePaths: ["/tmp/demo.txt"],
            tags: [.file, .filePath]
        )
        store.prepend(item)
        XCTAssertEqual(store.items.first?.filePaths, ["/tmp/demo.txt"])
        XCTAssertEqual(store.items.first?.representations.count, 2)
        XCTAssertTrue(store.items.first?.preview.contains("demo.txt") ?? false)
    }

    @MainActor
    func testBlocksAdultContentFavorite() {
        let store = ClipboardStore()
        let before = store.favorites.count
        store.addFavorite(name: "Bad", content: "free porn video")
        XCTAssertEqual(store.favorites.count, before)
    }

    @MainActor
    func testQRPayloadAndImage() {
        let store = ClipboardStore()
        let item = ClipboardHistoryItem(text: "https://example.com/qr", tags: [.url])
        XCTAssertEqual(store.qrPayload(for: item), "https://example.com/qr")
        XCTAssertNotNil(store.makeQRImage(for: item))

        let files = ClipboardHistoryItem(filePaths: ["/tmp/a.txt", "/tmp/b.txt"], tags: [.file])
        XCTAssertEqual(store.qrPayload(for: files), "/tmp/a.txt\n/tmp/b.txt")

        let imageOnly = ClipboardHistoryItem(imageData: Data([0x00]), tags: [.image])
        XCTAssertNil(store.qrPayload(for: imageOnly))
        XCTAssertNil(store.makeQRImage(for: imageOnly))
    }

    @MainActor
    func testCopyToPasteboardDoesNotRestack() {
        let store = ClipboardStore()
        let first = ClipboardHistoryItem(text: "alpha", tags: [.other])
        let second = ClipboardHistoryItem(text: "beta", tags: [.other])
        store.prepend(first)
        store.prepend(second)
        let countBefore = store.items.count

        store.copyToPasteboard(first)
        store.pollPasteboard()

        XCTAssertEqual(store.items.count, countBefore)
        XCTAssertEqual(store.items.first?.text, "beta")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "alpha")
    }

    @MainActor
    func testPruneByMaxHistoryCount() {
        let store = ClipboardStore()
        store.items = []
        store.maxHistoryCount = 3
        store.retentionDays = 365
        for i in 0..<5 {
            store.prepend(ClipboardHistoryItem(text: "item-\(i)", tags: [.text]))
        }
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(store.items.map(\.text), ["item-4", "item-3", "item-2"])
    }

    @MainActor
    func testClearAllHistory() {
        let store = ClipboardStore()
        store.items = [
            ClipboardHistoryItem(text: "keep-me", tags: [.text])
        ]
        store.selectedId = store.items.first?.id
        let favoritesBefore = store.favorites.count
        store.clearAllHistory()
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(store.selectedId)
        XCTAssertEqual(store.favorites.count, favoritesBefore)
    }
}
