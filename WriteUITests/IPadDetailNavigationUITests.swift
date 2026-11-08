import XCTest

@MainActor
final class IPadDetailNavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "The split layout is iPad only")
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshHistory", "-practiceMode", "trace", "-showWordPractice", "NO"]
        app.launch()
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private var progressButton: XCUIElement { app.buttons["Progress"] }
    private var progressTitle: XCUIElement { app.navigationBars["Progress"] }
    private var completedCount: XCUIElement { app.staticTexts["count.Completed"] }
    private var cardPractice: XCUIElement { app.buttons["Practice"] }
    private var cardNotebook: XCUIElement { app.buttons["Notebook"] }
    private var practiceScreen: XCUIElement { app.buttons["Smaller canvas"] }
    private let practiceLink = URL(string: "kakijun://practice?cp=3042")!

    private func letter(_ character: String) -> XCUIElement {
        app.buttons[character].firstMatch
    }

    private func openProgress() {
        XCTAssertTrue(progressButton.waitForExistence(timeout: 5))
        progressButton.tap()
        XCTAssertTrue(completedCount.waitForExistence(timeout: 5))
    }

    private func openPracticeLink() throws {
        guard #available(iOS 16.4, *) else {
            throw XCTSkip("XCUIApplication.open needs iOS 16.4")
        }
        app.open(practiceLink)
    }

    private func assertShowsCard(romaji: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(cardNotebook.waitForExistence(timeout: 5), "letter card is not showing", file: file, line: line)
        XCTAssertFalse(completedCount.exists, "Progress is still showing", file: file, line: line)
        XCTAssertTrue(app.staticTexts[romaji].firstMatch.waitForExistence(timeout: 5), file: file, line: line)
    }

    func testWidgetLinkOpensPracticeOverProgress() throws {
        openProgress()
        try openPracticeLink()
        XCTAssertTrue(practiceScreen.waitForExistence(timeout: 5), "widget link is hidden behind Progress")
        XCTAssertFalse(completedCount.exists)
    }

    func testWidgetLinkOpensPracticeOverASession() throws {
        app.buttons["session.practice"].tap()
        let end = app.buttons["End session"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))

        try openPracticeLink()
        XCTAssertTrue(practiceScreen.waitForExistence(timeout: 5), "widget link is hidden behind the session")
        XCTAssertFalse(end.exists)
    }

    func testLetterTapLeavesProgress() {
        openProgress()
        letter("あ").tap()
        assertShowsCard(romaji: "a")
    }

    func testTappingAnotherLetterLeavesProgress() {
        XCTAssertTrue(letter("あ").waitForExistence(timeout: 5))
        letter("あ").tap()
        assertShowsCard(romaji: "a")

        openProgress()
        letter("い").tap()
        assertShowsCard(romaji: "i")
    }

    func testTappingTheAlreadySelectedLetterLeavesProgress() {
        XCTAssertTrue(letter("あ").waitForExistence(timeout: 5))
        letter("あ").tap()
        assertShowsCard(romaji: "a")

        openProgress()
        letter("あ").tap()
        assertShowsCard(romaji: "a")
    }

    func testProgressHasABackButtonToTheSelectedLetter() {
        XCTAssertTrue(letter("あ").waitForExistence(timeout: 5))
        letter("あ").tap()
        assertShowsCard(romaji: "a")

        openProgress()
        let back = progressTitle.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        assertShowsCard(romaji: "a")
    }

    func testProgressBackButtonWorksWithNothingSelected() {
        openProgress()
        let back = progressTitle.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.staticTexts["Select a kanji"].waitForExistence(timeout: 5))
        XCTAssertFalse(completedCount.exists)
    }

    func testLetterTapLeavesASession() {
        let practice = app.buttons["session.practice"]
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        practice.tap()
        let end = app.buttons["End session"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))

        letter("あ").tap()
        assertShowsCard(romaji: "a")
        XCTAssertFalse(end.exists)
    }

    func testEndingASessionReturnsToTheLetter() {
        XCTAssertTrue(letter("あ").waitForExistence(timeout: 5))
        letter("あ").tap()
        assertShowsCard(romaji: "a")

        app.buttons["session.practice"].tap()
        let end = app.buttons["End session"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        assertShowsCard(romaji: "a")
    }

    func testProgressReplacesARunningSession() {
        app.buttons["session.practice"].tap()
        let end = app.buttons["End session"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))

        openProgress()
        XCTAssertFalse(end.exists)
    }

    func testPracticeStartedFromTheCardReturnsToTheCard() {
        XCTAssertTrue(letter("あ").waitForExistence(timeout: 5))
        letter("あ").tap()
        assertShowsCard(romaji: "a")

        cardPractice.tap()
        let back = app.buttons["Back"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertFalse(cardNotebook.exists)
        back.tap()
        assertShowsCard(romaji: "a")
    }
}
