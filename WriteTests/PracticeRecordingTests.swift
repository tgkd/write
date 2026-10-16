import XCTest
@testable import Write

@MainActor
final class PracticeRecordingTests: XCTestCase {

    private func makeKanjiData(strokeCount: Int) -> KanjiData {
        let strokes = (1...strokeCount).map { i in
            KanjiStroke(strokeNumber: i, pathData: "M10,10 L50,50", strokeType: nil)
        }
        return KanjiData(codePoint: "4e00", element: nil, strokes: strokes, components: [])
    }

    private func makeState(strokeCount: Int, mode: PracticeMode = .trace, isRecall: Bool = true) -> (PracticeState, Recorder) {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: strokeCount), mode: mode, isRecall: isRecall)
        let recorder = Recorder()
        state.onRunCompleted = { recorder.records.append($0) }
        return (state, recorder)
    }

    private func submit(_ state: PracticeState, matchedIndex: Int?, correctOrder: Bool = true) {
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(StrokeValidationResult(
            score: matchedIndex == nil ? 0.1 : 0.9,
            accepted: matchedIndex != nil,
            matchedStrokeIndex: matchedIndex,
            correctOrder: correctOrder,
            frechetDistance: 0.1
        ))
        state.acknowledgeResult()
    }

    private func complete(_ state: PracticeState) {
        for index in 0..<state.totalStrokes where !state.matchedStrokeIndices.contains(index) {
            submit(state, matchedIndex: index)
        }
    }

    func testCompletionRecordsOneRun() {
        let (state, recorder) = makeState(strokeCount: 2)
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 1_060)
        state.now = { start }
        submit(state, matchedIndex: nil)
        state.now = { end }
        complete(state)

        XCTAssertEqual(recorder.records.count, 1)
        let record = recorder.records[0]
        XCTAssertEqual(record.codePoint, "4e00")
        XCTAssertEqual(record.mode, PracticeRecord.recallMode)
        XCTAssertTrue(record.isRecall)
        XCTAssertEqual(record.misses, 1)
        XCTAssertFalse(record.revealed)
        XCTAssertFalse(record.exposed)
        XCTAssertEqual(record.startedAt, start)
        XCTAssertEqual(record.completedAt, end)
    }

    func testUndoAndRecompleteDoesNotRecordAgain() {
        let (state, recorder) = makeState(strokeCount: 2)
        complete(state)
        XCTAssertNotNil(state.undoLastStroke())
        complete(state)

        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(recorder.records.count, 1)
    }

    func testResetStartsANewRun() {
        let (state, recorder) = makeState(strokeCount: 2)
        complete(state)
        state.reset()
        complete(state)

        XCTAssertEqual(recorder.records.count, 2)
        XCTAssertNotEqual(recorder.records[0].id, recorder.records[1].id)
    }

    func testModeChangeStartsANewRun() {
        let (state, recorder) = makeState(strokeCount: 1, isRecall: false)
        complete(state)
        state.changeMode(.copy)
        complete(state)

        XCTAssertEqual(recorder.records.map(\.mode), ["trace", "freeDraw"])
    }

    func testPracticeRunsShowEverythingAndAreExposed() {
        let (state, recorder) = makeState(strokeCount: 1, mode: .copy, isRecall: false)
        XCTAssertFalse(state.hidesCharacter)
        XCTAssertFalse(state.hidesGuide)
        XCTAssertNil(state.nextHint)
        state.showNextHint()
        XCTAssertEqual(state.hint, .unused)
        complete(state)

        let record = recorder.records.first
        XCTAssertEqual(record?.mode, "freeDraw")
        XCTAssertEqual(record?.isRecall, false)
        XCTAssertEqual(record?.exposed, true)
        XCTAssertEqual(record?.revealed, false)
    }

    func testRecallStartsHiddenWithGuidedGuide() {
        let (state, _) = makeState(strokeCount: 1, mode: .copy)
        XCTAssertTrue(state.hidesCharacter)
        XCTAssertTrue(state.hidesGuide)
        XCTAssertEqual(state.mode, .strokeByStroke)
        XCTAssertEqual(state.nextHint, .character)
    }

    func testRecallIgnoresModeChanges() {
        let (state, _) = makeState(strokeCount: 2)
        submit(state, matchedIndex: 0)
        state.changeMode(.copy)

        XCTAssertEqual(state.mode, .strokeByStroke)
        XCTAssertEqual(state.matchedStrokeIndices, [0])
    }

    func testHintsShowCharacterThenStrokes() {
        let (state, _) = makeState(strokeCount: 1)
        state.showNextHint()
        XCTAssertEqual(state.hint, .character)
        XCTAssertFalse(state.hidesCharacter)
        XCTAssertTrue(state.hidesGuide)
        XCTAssertEqual(state.nextHint, .strokes)

        state.showNextHint()
        XCTAssertEqual(state.hint, .strokes)
        XCTAssertFalse(state.hidesGuide)
        XCTAssertNil(state.nextHint)

        state.showNextHint()
        XCTAssertEqual(state.hint, .strokes)
    }

    func testHintIsRecordedAndSurvivesReset() {
        let (state, recorder) = makeState(strokeCount: 1)
        state.showNextHint()
        state.reset()
        complete(state)

        XCTAssertFalse(state.hidesCharacter)
        XCTAssertEqual(recorder.records.first?.revealed, true)
        XCTAssertEqual(recorder.records.first?.exposed, false)
    }

    func testRecallEnforcesStrokeOrder() {
        let (state, recorder) = makeState(strokeCount: 2)
        submit(state, matchedIndex: 1, correctOrder: false)

        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
        XCTAssertEqual(state.attemptCount, 1)
        XCTAssertTrue(recorder.records.isEmpty)
    }

    func testRecordCarriesGradingConfigAndMissEvidence() {
        let (state, recorder) = makeState(strokeCount: 2)
        submit(state, matchedIndex: nil)
        state.disputeLastRejection()
        submit(state, matchedIndex: 1, correctOrder: false)
        complete(state)

        let record = recorder.records[0]
        XCTAssertEqual(record.misses, 2)
        XCTAssertEqual(record.evidence, MissEvidence(order: 1, notEvaluated: 1, disputed: 1))
        XCTAssertEqual(record.strictness, GradingStrictness.normal.rawValue)
        XCTAssertEqual(record.gradingVersion, ValidationConfig.gradingVersion)
    }

    func testRecordStoresTheStrictnessInUse() {
        var config = ValidationConfig.standard
        config.leniency = GradingStrictness.strict.leniency
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 1), config: config)
        let recorder = Recorder()
        state.onRunCompleted = { recorder.records.append($0) }
        complete(state)

        XCTAssertEqual(recorder.records.first?.strictness, GradingStrictness.strict.rawValue)
        XCTAssertEqual(recorder.records.first?.leniency, Double(GradingStrictness.strict.leniency))
    }

    func testResetStartsANewRunWithFreshEvidence() {
        let (state, recorder) = makeState(strokeCount: 1)
        submit(state, matchedIndex: nil)
        state.reset()
        complete(state)

        XCTAssertEqual(recorder.records.first?.evidence, MissEvidence())
        XCTAssertEqual(recorder.records.first?.misses, 0)
    }
}

@MainActor
private final class Recorder {
    var records: [PracticeRecord] = []
}
