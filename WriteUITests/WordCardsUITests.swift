import XCTest

@MainActor
final class WordCardsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(extra: [String] = []) {
        app.launchArguments = ["-uiTestingFreshHistory", "-practiceMode", "trace"] + extra
        app.launch()
    }

    private var practiceCard: XCUIElement { app.buttons["session.practice"] }
    private var wordsCard: XCUIElement {
        app.buttons[UIDevice.current.userInterfaceIdiom == .pad ? "session.writing" : "session.words"]
    }

    func testWordsCardShowsForANewUser() {
        launch()
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))
        XCTAssertTrue(wordsCard.waitForExistence(timeout: 5))
    }

    func testWordsCardShowsWhenTheOldSettingWasOff() {
        launch(extra: ["-showWordPractice", "NO"])
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))
        XCTAssertTrue(wordsCard.waitForExistence(timeout: 5))
    }

    func testSettingsHasNoWordPracticeSwitch() {
        launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["showWordPractice"].exists)
    }
}
