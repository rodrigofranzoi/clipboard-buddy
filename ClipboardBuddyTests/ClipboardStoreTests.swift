import XCTest
@testable import ClipboardBuddy
import BuddyCore
import BuddyTesting

final class ClipboardStoreTests: XCTestCase {
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
    }
}
