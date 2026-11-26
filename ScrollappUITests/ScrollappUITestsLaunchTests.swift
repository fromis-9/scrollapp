import XCTest

final class ScrollappUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() {
        let app = XCUIApplication.scrollappForTesting()
        app.launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: statusItem.screenshot())
        attachment.name = "Scrollapp Menu Bar Item"
        attachment.lifetime = .keepAlways
        add(attachment)

        statusItem.click()
        let start = app.menuItems["Start Auto-Scroll"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Scroll Mode"].exists)
        XCTAssertTrue(app.menuItems["Activation Method"].exists)
        XCTAssertTrue(app.menuItems["Settings"].exists)
        XCTAssertFalse(app.menuItems["Activation Methods"].exists)
    }
}
