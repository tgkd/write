import XCTest
@testable import Write

@MainActor
final class RejectionNoticeTests: XCTestCase {

    private func makeState(strokeCount: Int = 2) -> PracticeState {
        let strokes = (1...strokeCount).map { number in
            KanjiStroke(strokeNumber: number, pathData: "M10,10 L50,50", strokeType: nil)
        }
        let kanji = KanjiData(
            codePoint: "4e00",
            element: nil,
            strokes: strokes,
            components: []
        )
        return PracticeState(kanjiData: kanji, mode: .copy)
    }

    private func rejection(
        for evidence: StrokeEvidence,
        expectedEvidence: StrokeEvidence? = nil
    ) -> StrokeRejection? {
        let state = makeState()
        state.beginDrawing()
        state.beginValidation()
        var result = StrokeValidationResult(
            score: 0.1,
            accepted: false,
            matchedStrokeIndex: 0,
            correctOrder: true,
            frechetDistance: 0.9
        )
        result.evidence = evidence
        result.expectedEvidence = expectedEvidence
        state.processValidationResult(result)
        return state.lastRejection
    }

    func testWrongShapeInTheRightPlaceReportsShape() {
        let evidence = StrokeEvidence(shapePassed: false, positionPassed: true, proportionPassed: true)
        XCTAssertEqual(rejection(for: evidence), .shape)
    }

    func testWrongShapeInTheWrongPlaceReportsBoth() {
        let evidence = StrokeEvidence(shapePassed: false, positionPassed: false, proportionPassed: true)
        XCTAssertEqual(rejection(for: evidence), .shapeAndPosition)
    }

    func testRightShapeInTheWrongPlaceReportsPosition() {
        let evidence = StrokeEvidence(shapePassed: true, positionPassed: false, proportionPassed: true)
        XCTAssertEqual(rejection(for: evidence), .position)
    }

    func testRightShapeAndPlaceAtTheWrongSizeReportsSize() {
        let evidence = StrokeEvidence(shapePassed: true, positionPassed: true, proportionPassed: false)
        XCTAssertEqual(rejection(for: evidence), .size)
    }

    func testReasonComesFromTheExpectedStrokeNotTheBestCandidate() {
        let best = StrokeEvidence(shapePassed: false, positionPassed: true, proportionPassed: true)
        let expected = StrokeEvidence(shapePassed: true, positionPassed: false, proportionPassed: true)
        XCTAssertEqual(rejection(for: best, expectedEvidence: expected), .position)
    }

    func testValidatorReportsTheExpectedStrokesEvidence() {
        let canvas = CGSize(width: 300, height: 300)
        let strokes = [
            KanjiStroke(strokeNumber: 1, pathData: "M20,20 L90,20", strokeType: nil),
            KanjiStroke(strokeNumber: 2, pathData: "M20,40 L90,40", strokeType: nil)
        ]
        let samples = StrokeValidator.sampleReferenceStrokes(strokes, canvasSize: canvas, sampleCount: 50)
        let shifted = samples[0].map { CGPoint(x: $0.x, y: $0.y + 30) }

        let result = StrokeValidator.identifyStroke(
            userPoints: shifted,
            referenceSamples: samples,
            unmatchedIndices: [0, 1],
            canvasSize: canvas,
            expectedStrokeIndex: 0
        )

        XCTAssertEqual(result.expectedEvidence?.shapePassed, true)
        XCTAssertEqual(result.expectedEvidence?.positionPassed, false)
    }

    func testAStrokeFarFromTheExpectedOneReportsPosition() {
        let canvas = CGSize(width: 300, height: 300)
        let strokes = [KanjiStroke(strokeNumber: 1, pathData: "M5,5 L20,5", strokeType: nil)]
        let samples = StrokeValidator.sampleReferenceStrokes(strokes, canvasSize: canvas, sampleCount: 50)
        let far = samples[0].map { CGPoint(x: $0.x + 240, y: $0.y + 240) }

        let result = StrokeValidator.identifyStroke(
            userPoints: far,
            referenceSamples: samples,
            unmatchedIndices: [0],
            canvasSize: canvas,
            expectedStrokeIndex: 0
        )

        XCTAssertEqual(result.expectedEvidence?.positionPassed, false)
    }

    func testEveryReasonHasText() {
        let reasons: [StrokeRejection] = [
            .shape, .position, .shapeAndPosition, .size, .outOfFrame, .wrongOrder(drawnStroke: 1, expectedStroke: 0)
        ]
        for reason in reasons {
            XCTAssertFalse(reason.notice.isEmpty)
        }
    }

    func testNoticeClearsWhenTheNextStrokeBegins() {
        let state = makeState()
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(StrokeValidationResult(
            score: 0.1,
            accepted: false,
            matchedStrokeIndex: 0,
            correctOrder: true,
            frechetDistance: 0.9
        ))
        XCTAssertNotNil(state.lastRejection)

        state.noteStrokeBegan(.pencil)

        XCTAssertNil(state.lastRejection)
    }

    func testSettingDefaultsOnPersistsAndHidesTheNotice() throws {
        let suite = "RejectionNoticeTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
        }

        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.showRejectionReasons)
        XCTAssertEqual(settings.rejectionNotice(for: .position), StrokeRejection.position.notice)
        XCTAssertNil(settings.rejectionNotice(for: nil))

        settings.showRejectionReasons = false
        XCTAssertNil(settings.rejectionNotice(for: .position))
        XCTAssertFalse(AppSettings(defaults: defaults).showRejectionReasons)
    }
}
