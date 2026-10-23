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
        XCTAssertTrue(state.isGuideless)
        state.beginDrawing()
        state.beginValidation()
        var result = makeAcceptedResult(matchedIndex: 0, expectedIndex: 0)
        result.anchor = StrokeAnchor(referenceIndex: 0, userCentroid: CGPoint(x: 40, y: 50))
        state.processValidationResult(result)

        XCTAssertEqual(state.anchors, [StrokeAnchor(referenceIndex: 0, userCentroid: CGPoint(x: 40, y: 50))])

        _ = state.undoLastStroke()
        XCTAssertTrue(state.anchors.isEmpty)
    }

    func testRecallStaysGuidelessAfterHints() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2), isRecall: true)
        XCTAssertTrue(state.isGuideless)
        state.showNextHint()
        state.showNextHint()
        XCTAssertTrue(state.isGuideless)
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

    func testGuidedModesAreNotGuideless() {
        XCTAssertFalse(PracticeState(kanjiData: makeKanjiData(strokeCount: 1), mode: .trace).isGuideless)
        XCTAssertFalse(PracticeState(kanjiData: makeKanjiData(strokeCount: 1), mode: .strokeByStroke).isGuideless)
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

    private func reject(_ state: PracticeState, evidence: StrokeEvidence) {
        var result = makeRejectedResult()
        result.evidence = evidence
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(result)
        state.acknowledgeResult()
    }

    private func rejectOutOfOrder(_ state: PracticeState, drawn: Int) {
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(makeAcceptedResult(matchedIndex: drawn, expectedIndex: state.currentStrokeIndex))
        state.acknowledgeResult()
    }

    func testWrongOrderCountsAsAnOrderMiss() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))
        rejectOutOfOrder(state, drawn: 2)

        XCTAssertEqual(state.missEvidence, MissEvidence(order: 1))
        XCTAssertEqual(state.attemptCount, 1)
    }

    func testRejectionWithoutFlagsCountsAsNotEvaluated() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        reject(state, evidence: .notEvaluated)

        XCTAssertEqual(state.missEvidence, MissEvidence(notEvaluated: 1))
    }

    func testOneRejectionCanAddToSeveralCategories() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        reject(state, evidence: StrokeEvidence(shapePassed: false, positionPassed: false, proportionPassed: nil))
        reject(state, evidence: StrokeEvidence(shapePassed: true, positionPassed: false, proportionPassed: true))
        reject(state, evidence: StrokeEvidence(shapePassed: true, positionPassed: true, proportionPassed: false))

        XCTAssertEqual(state.missEvidence, MissEvidence(shape: 1, position: 2, proportion: 1))
        XCTAssertEqual(state.attemptCount, 3)
    }

    func testUndoKeepsMissEvidenceAndResetClearsIt() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))
        reject(state, evidence: StrokeEvidence(shapePassed: false))
        acceptStroke(state, matchedIndex: 0)
        _ = state.undoLastStroke()

        XCTAssertEqual(state.missEvidence, MissEvidence(shape: 1))

        state.reset()
        XCTAssertEqual(state.missEvidence, MissEvidence())
    }

    func testNoDisputeWithoutARejection() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        XCTAssertFalse(state.canDisputeLastRejection)

        state.disputeLastRejection()
        XCTAssertEqual(state.missEvidence.disputed, 0)
    }

    func testDisputeCountsOncePerRejection() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        reject(state, evidence: StrokeEvidence(positionPassed: false))
        XCTAssertTrue(state.canDisputeLastRejection)

        state.disputeLastRejection()
        state.disputeLastRejection()

        XCTAssertEqual(state.missEvidence.disputed, 1)
        XCTAssertFalse(state.canDisputeLastRejection)
        XCTAssertEqual(state.attemptCount, 1)
    }

    func testDisputeDoesNotAcceptTheStroke() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 2))
        reject(state, evidence: StrokeEvidence(shapePassed: false))
        state.disputeLastRejection()

        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
        XCTAssertTrue(state.anchors.isEmpty)
        XCTAssertEqual(state.currentStrokeIndex, 0)
        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.phase, .waitingForInput)
    }

    func testANewRejectionCanBeDisputedAgain() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))
        reject(state, evidence: StrokeEvidence(shapePassed: false))
        state.disputeLastRejection()
        rejectOutOfOrder(state, drawn: 1)

        XCTAssertTrue(state.canDisputeLastRejection)
        state.disputeLastRejection()
        XCTAssertEqual(state.missEvidence, MissEvidence(shape: 1, order: 1, disputed: 2))
    }

    func testAcceptanceUndoAndResetEndTheDispute() {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 3))
        reject(state, evidence: .notEvaluated)
        acceptStroke(state, matchedIndex: 0)
        XCTAssertFalse(state.canDisputeLastRejection)

        reject(state, evidence: .notEvaluated)
        _ = state.undoLastStroke()
        XCTAssertFalse(state.canDisputeLastRejection)

        reject(state, evidence: .notEvaluated)
        state.reset()
        XCTAssertFalse(state.canDisputeLastRejection)
    }

    private let boxCanvas = CGSize(width: 300, height: 300)

    private func makeEdgeKanjiData() -> KanjiData {
        KanjiData(
            codePoint: "4e09",
            element: nil,
            strokes: [
                KanjiStroke(strokeNumber: 1, pathData: "M25,30 L85,30", strokeType: nil),
                KanjiStroke(strokeNumber: 2, pathData: "M25,60 L85,60", strokeType: nil),
                KanjiStroke(strokeNumber: 3, pathData: "M0,20 L0,95", strokeType: nil),
            ],
            components: []
        )
    }

    private func makeBoxStates() -> [(label: String, state: PracticeState)] {
        [
            ("copy", PracticeState(kanjiData: makeEdgeKanjiData(), mode: .copy)),
            ("recall", PracticeState(kanjiData: makeEdgeKanjiData(), isRecall: true)),
            ("trace", PracticeState(kanjiData: makeEdgeKanjiData(), mode: .trace)),
        ]
    }

    private func reference(_ index: Int, of state: PracticeState) -> [CGPoint] {
        state.referenceSamples(canvasSize: boxCanvas)[index]
    }

    private func outOfBox(_ index: Int, of state: PracticeState) -> [CGPoint] {
        reference(index, of: state).map { CGPoint(x: $0.x - 0.03 * boxCanvas.width, y: $0.y) }
    }

    @discardableResult
    private func draw(_ points: [CGPoint], on state: PracticeState) -> StrokeValidationResult {
        let result = StrokeValidator.identifyStroke(
            userPoints: points,
            referenceSamples: state.referenceSamples(canvasSize: boxCanvas),
            unmatchedIndices: state.unmatchedIndices,
            canvasSize: boxCanvas,
            expectedStrokeIndex: state.currentStrokeIndex,
            anchors: state.isGuideless ? state.anchors : nil,
            config: state.validationConfig
        )
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(result)
        state.acknowledgeResult()
        return result
    }

    func testOutOfBoxStrokeMatchingALaterStrokeCountsAsBoundaryAndOrderEvidence() {
        for (label, state) in makeBoxStates() {
            draw(reference(0, of: state), on: state)
            XCTAssertEqual(state.matchedStrokeIndices, [0], label)
            let anchors = state.anchors

            let result = draw(outOfBox(2, of: state), on: state)

            XCTAssertEqual(result.matchedStrokeIndex, 2, label)
            XCTAssertFalse(result.correctOrder, label)
            XCTAssertEqual(result.geometryAccepted, true, label)
            XCTAssertEqual(state.lastRejection, .outOfFrame, label)
            XCTAssertEqual(state.missEvidence.boundary, 1, label)
            XCTAssertEqual(state.missEvidence.order, 1, label)
            XCTAssertEqual(state.missEvidence, MissEvidence(order: 1, boundary: 1), label)
            XCTAssertEqual(state.anchors, anchors, label)
            XCTAssertEqual(state.attemptCount, 1, label)
            XCTAssertEqual(state.matchedStrokeIndices, [0], label)
            XCTAssertEqual(state.currentStrokeIndex, 1, label)
        }
    }

    func testOutOfBoxStrokeThatFailedGeometryIsNotOrderEvidence() {
        for (label, state) in makeBoxStates() {
            draw(reference(0, of: state), on: state)
            XCTAssertEqual(state.matchedStrokeIndices, [0], label)
            let anchors = state.anchors

            let result = draw(Array(outOfBox(2, of: state).reversed()), on: state)

            XCTAssertEqual(result.matchedStrokeIndex, 2, label)
            XCTAssertFalse(result.correctOrder, label)
            XCTAssertEqual(result.geometryAccepted, false, label)
            XCTAssertEqual(state.lastRejection, .outOfFrame, label)
            XCTAssertEqual(state.missEvidence.order, 0, label)
            XCTAssertEqual(state.missEvidence.boundary, 1, label)
            XCTAssertEqual(state.missEvidence.shape, 1, label)
            XCTAssertEqual(state.anchors, anchors, label)
            XCTAssertEqual(state.attemptCount, 1, label)
        }
    }

    func testOutOfBoxExpectedStrokeCountsOnlyAsBoundaryEvidence() {
        for (label, state) in makeBoxStates() {
            var records: [PracticeRecord] = []
            state.onRunCompleted = { records.append($0) }
            draw(reference(0, of: state), on: state)
            draw(reference(1, of: state), on: state)
            XCTAssertEqual(state.matchedStrokeIndices, [0, 1], label)
            let anchors = state.anchors

            let result = draw(outOfBox(2, of: state), on: state)

            XCTAssertEqual(result.matchedStrokeIndex, 2, label)
            XCTAssertTrue(result.correctOrder, label)
            XCTAssertEqual(result.geometryAccepted, true, label)
            XCTAssertEqual(state.lastRejection, .outOfFrame, label)
            XCTAssertEqual(state.missEvidence, MissEvidence(boundary: 1), label)
            XCTAssertEqual(state.anchors, anchors, label)
            XCTAssertEqual(state.attemptCount, 1, label)
            XCTAssertEqual(state.currentStrokeIndex, 2, label)
            XCTAssertFalse(state.isComplete, label)

            draw(reference(2, of: state), on: state)

            XCTAssertTrue(state.isComplete, label)
            XCTAssertNil(state.lastRejection, label)
            XCTAssertEqual(records.map(\.evidence), [MissEvidence(boundary: 1)], label)
        }
    }

    func testOutOfBoxStrokeWithoutACandidateCountsAsBoundaryAndNotEvaluated() {
        for (label, state) in makeBoxStates() {
            let far = reference(2, of: state).map { CGPoint(x: $0.x - 200, y: $0.y) }

            let result = draw(far, on: state)

            XCTAssertNil(result.matchedStrokeIndex, label)
            XCTAssertEqual(state.lastRejection, .outOfFrame, label)
            XCTAssertEqual(state.missEvidence, MissEvidence(notEvaluated: 1, boundary: 1), label)
            XCTAssertEqual(state.attemptCount, 1, label)
        }
    }

    func testOutOfFrameNoticeAsksToKeepTheStrokeInside() {
        XCTAssertEqual(StrokeRejection.outOfFrame.notice, "That stroke went outside the box. Keep it inside.")
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
