import XCTest

@MainActor
final class RecallUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingFreshHistory", "-practiceMode", "trace"]
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

    private func dismissSearch() {
        for label in ["close", "Cancel"] where app.buttons[label].exists {
            app.buttons[label].tap()
            return
        }
    }

    private func goBack() {
        app.buttons["Back"].firstMatch.tap()
    }

    private var hiddenGlyph: XCUIElement { app.staticTexts["hiddenGlyph"] }
    private var answerGlyph: XCUIElement { app.staticTexts["answerGlyph"] }
    private var strokeGuide: XCUIElement { app.otherElements["strokeGuide"] }

    func testCharacterFromGridOffersGuideModesAndRemembersTheChoice() {
        openCharacter("一")
        XCTAssertTrue(answerGlyph.waitForExistence(timeout: 5))
        XCTAssertTrue(strokeGuide.exists)
        XCTAssertFalse(hiddenGlyph.exists)
        XCTAssertFalse(app.buttons["Show character"].exists)

        let copy = app.buttons["Copy"].firstMatch
        XCTAssertTrue(app.buttons["Trace"].firstMatch.isSelected)
        XCTAssertTrue(app.buttons["Guided"].firstMatch.exists)
        copy.tap()
        XCTAssertTrue(copy.isSelected)
        XCTAssertTrue(answerGlyph.exists)
        XCTAssertTrue(app.staticTexts["Copy the character without a guide."].exists)

        goBack()
        openCharacter("二")

        XCTAssertTrue(app.buttons["Copy"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Copy"].firstMatch.isSelected)
    }

    func testRecallSessionHidesTheAnswerUntilHints() {
        let recall = app.buttons["session.recall"]
        XCTAssertTrue(recall.waitForExistence(timeout: 5))
        recall.tap()

        XCTAssertTrue(hiddenGlyph.waitForExistence(timeout: 5))
        XCTAssertFalse(answerGlyph.exists)
        XCTAssertFalse(strokeGuide.exists)
        XCTAssertFalse(app.buttons["Trace"].exists)

        app.buttons["Show character"].tap()

        XCTAssertTrue(answerGlyph.waitForExistence(timeout: 5))
        XCTAssertFalse(strokeGuide.exists)

        app.buttons["Show next stroke"].tap()

        XCTAssertTrue(strokeGuide.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["No more hints"].isEnabled)

        app.buttons["arrow.counterclockwise"].tap()

        XCTAssertTrue(answerGlyph.exists)
        XCTAssertTrue(strokeGuide.exists)
    }

    func testCompletedPracticeIsRecordedButNotSentToReview() {
        let progressButton = app.buttons["Progress"]
        XCTAssertTrue(progressButton.waitForExistence(timeout: 5))
        progressButton.tap()
        XCTAssertTrue(app.staticTexts["Characters you needed a hint or retries for in Recall appear here."]
            .waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["count.Completed"].label, "0, Completed")
        app.navigationBars.buttons.firstMatch.tap()

        openCharacter("一")
        XCTAssertTrue(answerGlyph.waitForExistence(timeout: 5))

        let canvas = app.otherElements["drawingCanvas"]
        XCTAssertTrue(canvas.exists)
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.50))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.46))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 600, thenHoldForDuration: 0.05)

        goBack()
        dismissSearch()
        XCTAssertTrue(progressButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["session.review"].exists)
        progressButton.tap()

        let completed = app.staticTexts["count.Completed"]
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        XCTAssertEqual(completed.label, "1, Completed")
        XCTAssertEqual(app.staticTexts["count.Characters"].label, "1, Characters")
        XCTAssertTrue(app.staticTexts["Characters you needed a hint or retries for in Recall appear here."].exists)
    }
}
