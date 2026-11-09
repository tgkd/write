import XCTest

@MainActor
final class WritingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(enabled: Bool = true, mode: String = "free", ids: String = "w11,w02") {
        app.launchArguments = [
            "-uiTestingFreshHistory", "-showWordPractice", enabled ? "YES" : "NO",
            "-allowFingerDrawing", "YES", "-captureStrokes", "-writingMode", mode,
            "-gradingStrictness", "normal", "-showRejectionReasons", "YES",
            "-uiTestingWritingPromptIDs", ids
        ]
        app.launch()
    }

    private var card: XCUIElement { app.buttons["session.writing"] }
    private var canvases: XCUIElementQuery {
        app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "writing.canvas."))
    }

    private func open(mode: String = "free", ids: String = "w11,w02") throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Writing rows are iPad only")
        launch(mode: mode, ids: ids)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["writing.phrase"].waitForExistence(timeout: 5))
    }

    private func draw(in canvas: XCUIElement, start: CGVector = CGVector(dx: 0.2, dy: 0.3), end: CGVector = CGVector(dx: 0.8, dy: 0.7)) {
        canvas.coordinate(withNormalizedOffset: start).press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: end))
    }

    func testWritingReplacesBothIPadCardsAndIsGated() {
        launch()
        XCTAssertTrue(app.buttons["session.practice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["session.sentences"].exists)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["session.words"].exists)
        } else {
            XCTAssertFalse(card.exists)
            XCTAssertTrue(app.buttons["session.words"].exists)
        }
        app.terminate()
        launch(enabled: false)
        XCTAssertFalse(card.exists)
        XCTAssertFalse(app.buttons["session.words"].exists)
    }

    func testFreeDrawingUndoClearReflowAndCompletion() throws {
        try open()
        XCTAssertTrue(app.staticTexts["No checking"].exists)
        let canvas = canvases.firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let id = canvas.identifier
        let width = canvas.frame.width
        XCTAssertGreaterThan(canvases.element(boundBy: 3).frame.minY, canvas.frame.minY)
        draw(in: canvas)
        XCTAssertEqual(canvas.value as? String, "1")
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Writing portrait"
        portrait.lifetime = .keepAlways
        add(portrait)
        XCUIDevice.shared.orientation = .landscapeLeft
        let retained = app.otherElements[id]
        let reflow = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(self.canvases.element(boundBy: 3).frame.minY - retained.frame.minY) < 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reflow], timeout: 5), .completed)
        XCTAssertEqual(retained.value as? String, "1")
        XCTAssertEqual(retained.frame.width, width, accuracy: 1)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Writing landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCTAssertTrue(app.buttons["writing.next"].isHittable)
        app.buttons["writing.undo"].tap()
        XCTAssertEqual(retained.value as? String, "0")
        draw(in: retained)
        app.buttons["writing.clear"].tap()
        XCTAssertEqual(retained.value as? String, "0")
        let other = canvases.element(boundBy: 1)
        draw(in: other)
        XCTAssertEqual(other.value as? String, "1")
        app.buttons["writing.undo"].tap()
        XCTAssertEqual(other.value as? String, "0")
        app.buttons["writing.next"].tap()
        XCTAssertFalse(app.images["writing.ink.0.0"].exists)
        XCTAssertFalse(app.images["writing.ink.0.1"].exists)
        for _ in 0..<20 {
            if app.staticTexts["writing.complete"].exists { break }
            app.buttons["writing.next"].tap()
        }
        XCTAssertTrue(app.staticTexts["writing.complete"].waitForExistence(timeout: 5))
        app.buttons["writing.done"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
    }

    func testTraceAutoAdvancesAndKeepsFinishedInk() throws {
        try open(mode: "trace", ids: "t190270")
        let first = app.otherElements["writing.canvas.0.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(canvases.count, 1)
        draw(in: first, start: CGVector(dx: 0.101, dy: 0.498), end: CGVector(dx: 0.889, dy: 0.459))
        XCTAssertTrue(app.otherElements["writing.canvas.0.1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["writing.ink.0.0"].exists)
        app.buttons["writing.restart"].tap()
        XCTAssertTrue(app.otherElements["writing.canvas.0.0"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["writing.ink.0.0"].exists)
        app.buttons["writing.end"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
    }

    func testEmptyHintsRejectionAndPhraseRestart() throws {
        try open(mode: "empty", ids: "w11")
        XCTAssertFalse(app.otherElements["strokeGuide"].exists)
        XCTAssertFalse(app.staticTexts["answerGlyph"].exists)
        app.buttons["writing.hint"].tap()
        XCTAssertTrue(app.staticTexts["answerGlyph"].waitForExistence(timeout: 5))
        app.buttons["writing.hint"].tap()
        XCTAssertTrue(app.otherElements["strokeGuide"].waitForExistence(timeout: 5))
        draw(in: canvases.firstMatch, start: CGVector(dx: 0.05, dy: 0.05), end: CGVector(dx: 0.15, dy: 0.05))
        XCTAssertTrue(app.staticTexts["strokeNotice"].waitForExistence(timeout: 5))
        app.buttons["writing.restart"].tap()
        XCTAssertFalse(app.otherElements["strokeGuide"].exists)
        XCTAssertFalse(app.staticTexts["answerGlyph"].exists)
        app.buttons["writing.end"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
    }

    func testQueuedEmptyEndsClearlyWhenNoPromptsRemain() throws {
        try open(ids: "w01,w03")
        XCTAssertEqual(app.staticTexts["writing.sentenceProgress"].label, "Sentence 1 of 2")
        app.buttons["writing.mode"].tap()
        let empty = app.buttons["By strokes · Empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        empty.tap()
        XCTAssertTrue(app.staticTexts["writing.noRemainingEmpty"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["writing.sentenceProgress"].label, "Sentence 1 of 1")
        XCTAssertTrue(app.staticTexts["No checking"].exists)
        for _ in 0..<8 {
            if app.staticTexts["writing.complete"].exists { break }
            app.buttons["writing.next"].tap()
        }
        XCTAssertTrue(app.staticTexts["writing.complete"].waitForExistence(timeout: 5))
    }
}
