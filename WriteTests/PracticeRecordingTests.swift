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

    private func makeState(strokeCount: Int, mode: PracticeMode = .study) -> (PracticeState, Recorder) {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: strokeCount), mode: mode)
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
        XCTAssertEqual(record.practiceMode, .study)
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
        let (state, recorder) = makeState(strokeCount: 1)
        complete(state)
        state.changeMode(.trace)
        complete(state)

        XCTAssertEqual(recorder.records.map(\.practiceMode), [.study, .trace])
    }

    func testRevealIsRecordedAndSurvivesReset() {
        let (state, recorder) = makeState(strokeCount: 1)
        XCTAssertTrue(state.hidesAnswer)
        state.revealAnswer()
        XCTAssertFalse(state.hidesAnswer)
        state.reset()
        complete(state)

        XCTAssertFalse(state.hidesAnswer)
        XCTAssertEqual(recorder.records.first?.revealed, true)
        XCTAssertEqual(recorder.records.first?.exposed, false)
    }

    func testSwitchingFromACopyingModeMarksExposure() {
        let (state, recorder) = makeState(strokeCount: 1, mode: .trace)
        state.changeMode(.study)
        XCTAssertTrue(state.hidesAnswer)
        complete(state)

        XCTAssertEqual(recorder.records.first?.exposed, true)
        XCTAssertEqual(recorder.records.first?.revealed, false)
    }

    func testExposureSurvivesSwitchingBackToStudy() {
        let (state, recorder) = makeState(strokeCount: 1)
        state.changeMode(.freeDraw)
        state.changeMode(.study)
        state.reset()
        complete(state)

        XCTAssertEqual(recorder.records.first?.exposed, true)
    }

    func testMissingCueShowsAnswerAndMarksExposure() {
        let (state, recorder) = makeState(strokeCount: 1)
        state.markCueUnavailable()
        XCTAssertFalse(state.hidesAnswer)
        complete(state)

        XCTAssertEqual(recorder.records.first?.exposed, true)
        XCTAssertEqual(recorder.records.first?.revealed, false)
    }

    func testStudyEnforcesStrokeOrder() {
        let (state, recorder) = makeState(strokeCount: 2)
        submit(state, matchedIndex: 1, correctOrder: false)

        XCTAssertTrue(state.matchedStrokeIndices.isEmpty)
        XCTAssertEqual(state.attemptCount, 1)
        XCTAssertTrue(recorder.records.isEmpty)
    }

    func testOnlyStudyHidesAnswer() {
        let (state, _) = makeState(strokeCount: 1, mode: .freeDraw)
        XCTAssertFalse(state.hidesAnswer)
        state.changeMode(.study)
        XCTAssertTrue(state.hidesAnswer)
    }
}

@MainActor
private final class Recorder {
    var records: [PracticeRecord] = []
}
