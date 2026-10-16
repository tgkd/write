import XCTest
@testable import Write

// MARK: - PracticeMode Tests

final class PracticeModeTests: XCTestCase {

    func testTraceModeGhostVisibility() {
        let mode = PracticeMode.trace
        XCTAssertEqual(mode.ghostStrokeAlpha, 0.15)
        XCTAssertEqual(mode.currentStrokeAlpha, 0.5)
        XCTAssertFalse(mode.animateStrokeReveal)
        XCTAssertNil(mode.autoHintAfterMisses)
    }

    func testStrokeByStrokeModeGhostVisibility() {
        let mode = PracticeMode.strokeByStroke
        XCTAssertNil(mode.ghostStrokeAlpha)
        XCTAssertEqual(mode.currentStrokeAlpha, 0.5)
        XCTAssertTrue(mode.animateStrokeReveal)
        XCTAssertEqual(mode.autoHintAfterMisses, 3)
    }

    func testCopyModeGhostVisibility() {
        let mode = PracticeMode.copy
        XCTAssertNil(mode.ghostStrokeAlpha)
        XCTAssertNil(mode.currentStrokeAlpha)
        XCTAssertFalse(mode.animateStrokeReveal)
        XCTAssertNil(mode.autoHintAfterMisses)
    }

    func testCopyKeepsTheStoredRawValue() {
        XCTAssertEqual(PracticeMode.copy.rawValue, "freeDraw")
        XCTAssertEqual(PracticeMode(rawValue: "freeDraw"), .copy)
        XCTAssertNil(PracticeMode(rawValue: "study"))
    }

    func testAllCasesAreOrderedByAssistance() {
        XCTAssertEqual(PracticeMode.allCases, [.trace, .strokeByStroke, .copy])
    }

    func testDisplayNames() {
        XCTAssertEqual(PracticeMode.trace.displayName, "Trace")
        XCTAssertEqual(PracticeMode.strokeByStroke.displayName, "Guided")
        XCTAssertEqual(PracticeMode.copy.displayName, "Copy")
    }
}

// MARK: - PracticeState Tests

@MainActor
final class PracticeStateTests: XCTestCase {

    private func makeKanjiData(strokeCount: Int) -> KanjiData {
        let strokes = (1...strokeCount).map { i in
            KanjiStroke(
                strokeNumber: i,
                pathData: "M10,10 L50,50",
                strokeType: nil
            )
        }
        return KanjiData(
            codePoint: "4e00",
            element: nil,
            strokes: strokes,
            components: []
        )
    }

    private func makeAcceptedResult(matchedIndex: Int, expectedIndex: Int) -> StrokeValidationResult {
        StrokeValidationResult(
            score: 0.9,
            accepted: true,
            matchedStrokeIndex: matchedIndex,
            correctOrder: matchedIndex == expectedIndex,
            frechetDistance: 0.1
        )
    }

    private func makeRejectedResult() -> StrokeValidationResult {
        StrokeValidationResult(
            score: 0.1,
            accepted: false,
            matchedStrokeIndex: nil,
            correctOrder: false,
            frechetDistance: 0.8
        )
    }

    /// Drives one accepted stroke through the full phase machine.
    private func acceptStroke(_ state: PracticeState, matchedIndex: Int) {
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(
            makeAcceptedResult(matchedIndex: matchedIndex, expectedIndex: matchedIndex)
        )
        state.acknowledgeResult()
    }

    // MARK: - Undo

    func testUndoRemovesLastAcceptedStrokeInOrder() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))
        acceptStroke(state, matchedIndex: 0)
        acceptStroke(state, matchedIndex: 1)

        XCTAssertEqual(state.undoLastStroke(), 1)
        XCTAssertEqual(state.matchedStrokeIndices, [0])
        XCTAssertEqual(state.currentStrokeIndex, 1)
    }

    func testUndoRemovesLastDrawnNotHighestIndex() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 6))
        acceptStroke(state, matchedIndex: 5)
        acceptStroke(state, matchedIndex: 2)

        XCTAssertEqual(state.undoLastStroke(), 2,
            "Undo must return the last-drawn stroke (2), not the highest index (5)")
        XCTAssertEqual(state.matchedStrokeIndices, [5])

        XCTAssertEqual(state.undoLastStroke(), 5)
        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
        XCTAssertNil(state.undoLastStroke())
    }

    func testResetClearsAcceptanceOrder() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        acceptStroke(state, matchedIndex: 0)
        state.reset()

        XCTAssertNil(state.undoLastStroke(), "Reset must clear the undo stack")
        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
    }

    // MARK: - Initial state

    func testInitialState() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))
        XCTAssertEqual(state.phase, .waitingForInput)
        XCTAssertEqual(state.currentStrokeIndex, 0)
        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
        XCTAssertEqual(state.attemptCount, 0)
        XCTAssertEqual(state.consecutiveMisses, 0)
        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.totalStrokes, 3)
        XCTAssertEqual(state.unmatchedIndices, [0, 1, 2])
    }

    // MARK: - Phase transitions

    func testBeginDrawingTransition() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        state.beginDrawing()
        XCTAssertEqual(state.phase, .userDrawing)
    }

    func testBeginDrawingOnlyFromWaiting() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        state.beginDrawing()
        state.beginValidation()
        // Try to begin drawing from validating - should not change phase
        state.beginDrawing()
        XCTAssertEqual(state.phase, .validating)
    }

    func testBeginValidationTransition() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        state.beginDrawing()
        state.beginValidation()
        XCTAssertEqual(state.phase, .validating)
    }

    func testBeginValidationOnlyFromDrawing() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        // Try from waitingForInput - should not change
        state.beginValidation()
        XCTAssertEqual(state.phase, .waitingForInput)
    }

    // MARK: - Stroke acceptance

    func testStrokeAccepted() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))
        state.beginDrawing()
        state.beginValidation()

        let result = makeAcceptedResult(matchedIndex: 0, expectedIndex: 0)
        state.processValidationResult(result)

        XCTAssertEqual(state.phase, .strokeAccepted(strokeIndex: 0))
        XCTAssertEqual(state.currentStrokeIndex, 1)
        XCTAssertEqual(state.matchedStrokeIndices, [0])
        XCTAssertEqual(state.consecutiveMisses, 0)
        XCTAssertFalse(state.isComplete)
    }

    func testStrokeAcceptedAcknowledge() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))
        state.acknowledgeResult()
        XCTAssertEqual(state.phase, .waitingForInput)
    }

    // MARK: - Stroke rejection

    func testStrokeRejected() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        state.beginDrawing()
        state.beginValidation()

        state.processValidationResult(makeRejectedResult())

        XCTAssertEqual(state.phase, .strokeRejected)
        XCTAssertEqual(state.attemptCount, 1)
        XCTAssertEqual(state.consecutiveMisses, 1)
        XCTAssertEqual(state.currentStrokeIndex, 0)
    }

    func testStrokeRejectedAcknowledge() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeRejectedResult())
        state.acknowledgeResult()
        XCTAssertEqual(state.phase, .waitingForInput)
    }

    func testOutOfOrderStrokeRejectedInTraceMode() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3), mode: .trace)
        state.beginDrawing()
        state.beginValidation()

        let result = StrokeValidationResult(
            score: 0.9,
            accepted: true,
            matchedStrokeIndex: 1,
            correctOrder: false,
            frechetDistance: 0.1
        )
        state.processValidationResult(result)

        XCTAssertEqual(state.phase, .strokeRejected)
        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
    }

    func testOutOfOrderStrokeRejectedInCopyMode() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3), mode: .copy)
        state.beginDrawing()
        state.beginValidation()

        let result = StrokeValidationResult(
            score: 0.9,
            accepted: true,
            matchedStrokeIndex: 2,
            correctOrder: false,
            frechetDistance: 0.1
        )
        state.processValidationResult(result)

        XCTAssertEqual(state.phase, .strokeRejected)
        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
        XCTAssertEqual(state.lastRejection, .wrongOrder(drawnStroke: 2, expectedStroke: 0))
    }

    func testWrongOrderNoticeNamesBothStrokes() {
        let rejection = StrokeRejection.wrongOrder(drawnStroke: 2, expectedStroke: 0)
        XCTAssertEqual(rejection.notice, "Right shape, wrong order: that was stroke 3. Draw stroke 1 first.")
        XCTAssertNil(StrokeRejection.shape.notice)
    }

    func testBadShapeIsNotReportedAsWrongOrder() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3), mode: .copy)
        state.beginDrawing()
        state.beginValidation()

        let result = StrokeValidationResult(
            score: 0.1,
            accepted: false,
            matchedStrokeIndex: 2,
            correctOrder: false,
            frechetDistance: 0.9
        )
        state.processValidationResult(result)

        XCTAssertEqual(state.lastRejection, .shape)
    }

    func testWrongOrderClearsOnTheNextAcceptedStroke() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3), mode: .copy)
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(StrokeValidationResult(
            score: 0.9,
            accepted: true,
            matchedStrokeIndex: 1,
            correctOrder: false,
            frechetDistance: 0.1
        ))
        state.acknowledgeResult()
        XCTAssertNotNil(state.lastRejection)

        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))

        XCTAssertNil(state.lastRejection)
    }

    func testAcceptedStrokesBecomeAnchorsAndUndoRemovesThem() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), mode: .copy)
        XCTAssertTrue(state.usesRelativePlacement)
        state.beginDrawing()
        state.beginValidation()
        var result = makeAcceptedResult(matchedIndex: 0, expectedIndex: 0)
        result.anchor = StrokeAnchor(referenceIndex: 0, userCentroid: CGPoint(x: 40, y: 50))
        state.processValidationResult(result)

        XCTAssertEqual(state.anchors, [StrokeAnchor(referenceIndex: 0, userCentroid: CGPoint(x: 40, y: 50))])

        _ = state.undoLastStroke()
        XCTAssertTrue(state.anchors.isEmpty)
    }

    func testRecallKeepsRelativePlacementAfterHints() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), isRecall: true)
        XCTAssertTrue(state.usesRelativePlacement)
        state.showNextHint()
        state.showNextHint()
        XCTAssertTrue(state.usesRelativePlacement)
    }

    func testStartMarkerShowsUntilTheFirstStrokeInCopy() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), mode: .copy)
        XCTAssertNotNil(state.startMarker)
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))
        XCTAssertNil(state.startMarker)
    }

    func testStartMarkerHidesOnceRecallShowsTheGuide() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), isRecall: true)
        XCTAssertNotNil(state.startMarker)
        state.showNextHint()
        XCTAssertNotNil(state.startMarker)
        state.showNextHint()
        XCTAssertNil(state.startMarker)
    }

    func testNoStartMarkerWhenTheGuideIsDrawn() {
        XCTAssertNil(PracticeState(kanjiData: makeKanjiData(strokeCount: 2), mode: .trace).startMarker)
        XCTAssertNil(PracticeState(kanjiData: makeKanjiData(strokeCount: 2), mode: .strokeByStroke).startMarker)
    }

    func testGuidedModesUseAbsolutePlacement() {
        XCTAssertFalse(PracticeState(kanjiData: makeKanjiData(strokeCount: 1), mode: .trace).usesRelativePlacement)
        XCTAssertFalse(PracticeState(kanjiData: makeKanjiData(strokeCount: 1), mode: .strokeByStroke).usesRelativePlacement)
    }

    func testResetClearsTheRejection() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeRejectedResult())
        XCTAssertNotNil(state.lastRejection)

        state.reset()

        XCTAssertNil(state.lastRejection)
    }

    // MARK: - Completion

    func testCompletion() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))

        // Accept stroke 0
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))
        XCTAssertFalse(state.isComplete)
        state.acknowledgeResult()

        // Accept stroke 1
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 1, expectedIndex: 1))
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.matchedStrokeIndices, [0, 1])
    }

    // MARK: - Consecutive misses and auto-hint

    func testConsecutiveMissesCounter() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), mode: .strokeByStroke)

        for i in 1...3 {
            state.beginDrawing()
            state.beginValidation()
            state.processValidationResult(makeRejectedResult())
            XCTAssertEqual(state.consecutiveMisses, i)
            state.acknowledgeResult()
        }
    }

    func testConsecutiveMissesResetOnAccept() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))

        // Miss twice
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeRejectedResult())
        state.acknowledgeResult()

        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeRejectedResult())
        state.acknowledgeResult()
        XCTAssertEqual(state.consecutiveMisses, 2)

        // Accept
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))
        XCTAssertEqual(state.consecutiveMisses, 0)
    }

    func testAutoHintTriggersInStrokeByStrokeMode() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), mode: .strokeByStroke)
        XCTAssertFalse(state.shouldShowAutoHint)

        for _ in 1...2 {
            state.beginDrawing()
            state.beginValidation()
            state.processValidationResult(makeRejectedResult())
            state.acknowledgeResult()
        }
        XCTAssertFalse(state.shouldShowAutoHint)

        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeRejectedResult())
        state.acknowledgeResult()
        XCTAssertTrue(state.shouldShowAutoHint)
    }

    func testAutoHintDoesNotTriggerInTraceMode() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), mode: .trace)

        for _ in 1...5 {
            state.beginDrawing()
            state.beginValidation()
            state.processValidationResult(makeRejectedResult())
            state.acknowledgeResult()
        }
        XCTAssertFalse(state.shouldShowAutoHint)
    }

    // MARK: - Reset

    func testReset() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))

        // Progress through some strokes
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))
        state.acknowledgeResult()

        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeRejectedResult())
        state.acknowledgeResult()

        state.reset()

        XCTAssertEqual(state.phase, .waitingForInput)
        XCTAssertEqual(state.currentStrokeIndex, 0)
        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
        XCTAssertEqual(state.attemptCount, 0)
        XCTAssertEqual(state.consecutiveMisses, 0)
        XCTAssertFalse(state.isComplete)
    }

    // MARK: - Mode change

    func testChangeModeResetsState() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), mode: .trace)

        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))
        state.acknowledgeResult()

        state.changeMode(.copy)

        XCTAssertEqual(state.mode, .copy)
        XCTAssertEqual(state.phase, .waitingForInput)
        XCTAssertEqual(state.currentStrokeIndex, 0)
        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
    }

    // MARK: - Guard conditions

    func testProcessResultOnlyFromValidating() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        // Try from waitingForInput
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))
        XCTAssertEqual(state.phase, .waitingForInput)
        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
    }

    func testAcknowledgeOnlyFromResultPhases() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        state.beginDrawing()
        state.acknowledgeResult()
        // Should still be in userDrawing since acknowledge doesn't work from there
        XCTAssertEqual(state.phase, .userDrawing)
    }

    // MARK: - Unmatched indices

    func testUnmatchedIndicesDecrease() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))
        XCTAssertEqual(state.unmatchedIndices, [0, 1, 2])

        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: 0, expectedIndex: 0))
        XCTAssertEqual(state.unmatchedIndices, [1, 2])
    }
}

// MARK: - FeedbackOverlayView Tests

@MainActor
final class FeedbackOverlayViewTests: XCTestCase {

    func testShowAcceptedAddsLayer() {
        let view = FeedbackOverlayView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let points = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50), CGPoint(x: 90, y: 90)]

        view.showAccepted(points: points)
        XCTAssertEqual(view.layer.sublayers?.count ?? 0, 1)
    }

    func testShowRejectedAddsLayer() {
        let view = FeedbackOverlayView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let points = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)]

        view.showRejected(points: points)
        XCTAssertEqual(view.layer.sublayers?.count ?? 0, 1)
    }

    func testShowAcceptedUsesGreenColor() {
        let view = FeedbackOverlayView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let points = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)]

        view.showAccepted(points: points)

        let shapeLayer = view.layer.sublayers?.first as? CAShapeLayer
        XCTAssertNotNil(shapeLayer)
        XCTAssertEqual(shapeLayer?.strokeColor, UIColor.systemGreen.cgColor)
    }

    func testShowRejectedUsesRedColor() {
        let view = FeedbackOverlayView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let points = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)]

        view.showRejected(points: points)

        let shapeLayer = view.layer.sublayers?.first as? CAShapeLayer
        XCTAssertNotNil(shapeLayer)
        XCTAssertEqual(shapeLayer?.strokeColor, UIColor.systemRed.cgColor)
    }

    func testClearAllRemovesLayers() {
        let view = FeedbackOverlayView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let points = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)]

        view.showAccepted(points: points)
        view.showRejected(points: points)
        XCTAssertEqual(view.layer.sublayers?.count ?? 0, 2)

        view.clearAll()
        XCTAssertNil(view.layer.sublayers)
    }

    func testIgnoresSinglePoint() {
        let view = FeedbackOverlayView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        view.showAccepted(points: [CGPoint(x: 10, y: 10)])
        XCTAssertNil(view.layer.sublayers)
    }
}
