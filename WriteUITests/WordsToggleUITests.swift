import XCTest

@MainActor
final class WordsToggleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(showWordPractice: Bool) {
        app.launchArguments = [
            "-uiTestingFreshHistory",
            "-practiceMode", "trace",
            "-showWordPractice", showWordPractice ? "YES" : "NO"
        ]
        app.launch()
    }

    private var practiceCard: XCUIElement { app.buttons["session.practice"] }
    private var wordsCard: XCUIElement { app.buttons["session.words"] }

    func testWordsCardIsHiddenWhenTheSettingIsOff() {
        launch(showWordPractice: false)
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))
        XCTAssertFalse(wordsCard.exists)
    }

    func testWordsCardShowsWhenTheSettingIsOn() {
        launch(showWordPractice: true)
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))
        XCTAssertTrue(wordsCard.waitForExistence(timeout: 5))
    }

    func testTurningTheSettingOnShowsTheWordsCard() {
        launch(showWordPractice: false)
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))
        XCTAssertFalse(wordsCard.exists)

        app.buttons["Settings"].tap()

        let toggle = app.switches["showWordPractice"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")

        app.buttons["Done"].tap()

        XCTAssertTrue(wordsCard.waitForExistence(timeout: 5))
    }
}
