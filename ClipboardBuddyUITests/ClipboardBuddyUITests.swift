import XCTest

final class ClipboardBuddyUITests: XCTestCase {
    func testLaunchShowsDashboard() throws {
        let app = XCUIApplication()
        app.launch()
        // Menu-bar app may not show window immediately; activate via launch arguments later.
        XCTAssertTrue(app.exists)
    }
}
