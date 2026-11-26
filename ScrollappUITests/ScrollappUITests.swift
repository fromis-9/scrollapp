import XCTest

final class ScrollappUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesWithoutPermissionPrompt() {
        let app = XCUIApplication.scrollappForTesting()
        app.launch()
        XCTAssertTrue([.runningBackground, .runningForeground].contains(app.state))
        XCTAssertFalse(app.staticTexts["Scrollapp Permissions"].exists)
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication.scrollappForTesting().launch()
        }
    }
}

extension XCUIApplication {
    @MainActor
    static func scrollappForTesting() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SCROLLAPP_UI_TESTING"] = "1"
        app.launchArguments += ["-hidesMenuBarIcon", "NO"]
        return app
    }
}
