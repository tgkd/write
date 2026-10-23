import XCTest

@MainActor
final class SentenceSessionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(showWordPractice: Bool) {
        app.launchArguments = [
            "-uiTestingFreshHistory",
            "-practiceMode", "trace",
            "-showWordPractice", showWordPractice ? "YES" : "NO"
        ]
        app.launch()
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var practiceCard: XCUIElement { app.buttons["session.practice"] }
    private var wordsCard: XCUIElement { app.buttons["session.words"] }
    private var sentencesCard: XCUIElement { app.buttons["session.sentences"] }

    func testSentencesCardShowsOnlyOnIPadWithTheSettingOn() {
        launch(showWordPractice: true)
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))
        XCTAssertTrue(wordsCard.waitForExistence(timeout: 5))
        if isPad {
            XCTAssertTrue(sentencesCard.waitForExistence(timeout: 5))
        } else {
            XCTAssertFalse(sentencesCard.exists)
        }
    }

    func testSentencesCardIsHiddenWhenTheSettingIsOff() {
        launch(showWordPractice: false)
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))
        XCTAssertFalse(sentencesCard.exists)
    }

    func testSentenceSessionFitsPortraitAndLandscape() throws {
        try XCTSkipUnless(isPad, "Sentences are iPad only")
        launch(showWordPractice: true)
        XCTAssertTrue(sentencesCard.waitForExistence(timeout: 5))
        sentencesCard.tap()

        XCTAssertTrue(app.staticTexts["sentencePrompt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sentenceTranslation"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["sentenceCell.0"].exists)

        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            let restart = app.buttons["sentence.restart"]
            XCTAssertTrue(restart.waitForExistence(timeout: 5))
            XCTAssertTrue(restart.isHittable)
            XCTAssertTrue(app.buttons["sentence.undo"].isHittable)
            XCTAssertTrue(app.staticTexts["sentencePrompt"].isHittable)
        }

        app.buttons["sentence.end"].tap()
        XCTAssertTrue(sentencesCard.waitForExistence(timeout: 5))
    }
}
