import XCTest

@MainActor
final class StudyModeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshHistory"]
        app.launch()
    }

    private func openCharacter(_ character: String) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(character)
        let cell = app.buttons[character].firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
    }

    private func switchMode(from current: String, to target: String) {
        let menu = app.buttons[current].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let option = app.buttons[target].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
    }

    private func dismissSearch() {
        for label in ["close", "Cancel"] where app.buttons[label].exists {
            app.buttons[label].tap()
            return
        }
    }

    private var revealButton: XCUIElement { app.buttons["Reveal answer"] }
    private var answerGlyph: XCUIElement { app.staticTexts["answerGlyph"] }
    private var strokeGuide: XCUIElement { app.otherElements["strokeGuide"] }

    func testStudyHidesAnswerUntilRevealAndStaysRevealedAfterReset() {
        openCharacter("一")
        XCTAssertTrue(answerGlyph.waitForExistence(timeout: 5))
        XCTAssertTrue(strokeGuide.exists)

        switchMode(from: "Trace", to: "Study")

        XCTAssertTrue(revealButton.waitForExistence(timeout: 5))
        XCTAssertFalse(answerGlyph.exists)
        XCTAssertFalse(strokeGuide.exists)
        XCTAssertTrue(app.staticTexts["one, one radical (no.1)"].exists)

        revealButton.tap()

        XCTAssertTrue(answerGlyph.waitForExistence(timeout: 5))
        XCTAssertTrue(strokeGuide.exists)

        app.buttons["arrow.counterclockwise"].tap()

        XCTAssertTrue(answerGlyph.exists)
        XCTAssertFalse(revealButton.exists)
    }

    func testAcceptedStrokeInStudyKeepsGuideHiddenAndIsRecorded() {
        let progressButton = app.buttons["Progress"]
        XCTAssertTrue(progressButton.waitForExistence(timeout: 5))
        progressButton.tap()
        XCTAssertTrue(app.staticTexts["Completed Study runs where you used Reveal or needed retries appear here."]
            .waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["count.Completed"].label, "0, Completed")
        app.navigationBars.buttons.firstMatch.tap()

        openCharacter("一")
        switchMode(from: "Trace", to: "Study")
        XCTAssertTrue(revealButton.waitForExistence(timeout: 5))

        let canvas = app.otherElements["drawingCanvas"]
        XCTAssertTrue(canvas.exists)
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.50))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.46))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 600, thenHoldForDuration: 0.05)

        XCTAssertFalse(strokeGuide.exists)
        XCTAssertTrue(revealButton.exists)

        app.buttons["Back"].firstMatch.tap()
        dismissSearch()
        XCTAssertTrue(progressButton.waitForExistence(timeout: 5))
        progressButton.tap()

        let completed = app.staticTexts["count.Completed"]
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        XCTAssertEqual(completed.label, "1, Completed")
        XCTAssertEqual(app.staticTexts["count.Characters"].label, "1, Characters")
        XCTAssertTrue(app.staticTexts["Completed Study runs where you used Reveal or needed retries appear here."].exists)
    }
}
