import UIKit
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

    private func submit(
        _ state: PracticeState,
        matchedIndex: Int?,
        correctOrder: Bool = true,
        canvasSize: CGSize? = nil
    ) {
        process(state, StrokeValidationResult(
            score: matchedIndex == nil ? 0.1 : 0.9,
            accepted: matchedIndex != nil,
            matchedStrokeIndex: matchedIndex,
            correctOrder: correctOrder,
            frechetDistance: 0.1
        ), canvasSize: canvasSize)
    }

    private func process(_ state: PracticeState, _ result: StrokeValidationResult, canvasSize: CGSize? = nil) {
        state.beginDrawing()
        state.beginValidation()
        state.processValidationResult(result, canvasSize: canvasSize)
        state.acknowledgeResult()
    }

    private func reject(_ state: PracticeState, evidence: StrokeEvidence) {
        var result = StrokeValidationResult(
            score: 0.1,
            accepted: false,
            matchedStrokeIndex: nil,
            correctOrder: false,
            frechetDistance: 0.8
        )
        result.evidence = evidence
        process(state, result)
    }

    private func rejectOutOfOrder(_ state: PracticeState, drawn: Int) {
        submit(state, matchedIndex: drawn, correctOrder: false)
    }

    private func rejectOutOfFrame(_ state: PracticeState) {
        var result = StrokeValidationResult(
            score: 0.9,
            accepted: false,
            matchedStrokeIndex: state.currentStrokeIndex,
            correctOrder: true,
            frechetDistance: 0.1
        )
        result.geometryAccepted = true
        result.evidence = StrokeEvidence(shapePassed: true, positionPassed: true, boundaryPassed: false)
        process(state, result)
    }

    private func total(of strokes: [StrokeStat]) -> MissEvidence {
        strokes.map(\.evidence).reduce(into: MissEvidence()) { sum, evidence in
            sum.shape += evidence.shape
            sum.position += evidence.position
            sum.proportion += evidence.proportion
            sum.order += evidence.order
            sum.notEvaluated += evidence.notEvaluated
            sum.disputed += evidence.disputed
            sum.boundary += evidence.boundary
        }
    }

    private var strictConfig: ValidationConfig {
        var config = ValidationConfig.standard
        config.leniency = GradingStrictness.strict.leniency
        return config
    }

    private func input(of kinds: [InputKind?]) -> String? {
        let (state, recorder) = makeState(strokeCount: kinds.count)
        for (index, kind) in kinds.enumerated() {
            if let kind {
                state.noteStrokeBegan(kind)
            }
            submit(state, matchedIndex: index)
        }
        return recorder.records.first?.input
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

    func testRunContextIsCopiedIntoTheRecord() throws {
        let session = UUID()
        let state = PracticeState(
            kanjiData: makeKanjiData(strokeCount: 1),
            isRecall: true,
            context: RunContext(sessionID: session, origin: .reviewSession, slot: 3)
        )
        let recorder = Recorder()
        state.onRunCompleted = { recorder.records.append($0) }
        complete(state)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.sessionID, session)
        XCTAssertEqual(record.slot, 3)
        XCTAssertEqual(record.origin, "reviewSession")
    }

    func testRunWithoutContextLeavesItOut() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        complete(state)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertNil(record.sessionID)
        XCTAssertNil(record.slot)
        XCTAssertNil(record.origin)
    }

    func testNewRecordsAlwaysStateInterruptionAndConfigChange() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        complete(state)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.interrupted, false)
        XCTAssertEqual(record.configChanged, false)
        XCTAssertEqual(record.undos, 0)
        XCTAssertNil(record.input)
        XCTAssertNil(record.canvasWidth)
        XCTAssertNil(record.canvasHeight)
        XCTAssertNil(record.shownAt)
        XCTAssertNil(record.firstTouchAt)
    }

    func testRecallRunRecordsTheCueOrder() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        state.cueOrder = .readingsFirst
        complete(state)

        XCTAssertEqual(try XCTUnwrap(recorder.records.first).cueOrder, "readingsFirst")
    }

    func testRecallRunRecordsTheDefaultCueOrder() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        complete(state)

        XCTAssertEqual(try XCTUnwrap(recorder.records.first).cueOrder, "meaningsFirst")
    }

    func testPracticeRunLeavesTheCueOrderOut() throws {
        let (state, recorder) = makeState(strokeCount: 1, isRecall: false)
        state.cueOrder = .readingsFirst
        complete(state)

        XCTAssertNil(try XCTUnwrap(recorder.records.first).cueOrder)
    }

    func testCueAudioPlaysAreCountedPerRun() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        state.noteCueAudioPlayed()
        state.noteCueAudioPlayed()
        state.noteCueAudioPlayed()
        complete(state)

        XCTAssertEqual(try XCTUnwrap(recorder.records.first).cueAudioPlays, 3)
    }

    func testRunWithoutAudioLeavesThePlayCountOut() throws {
        let (state, recorder) = makeState(strokeCount: 1, isRecall: false)
        complete(state)

        XCTAssertNil(try XCTUnwrap(recorder.records.first).cueAudioPlays)
    }

    func testResetStartsTheAudioCountAgain() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        state.noteCueAudioPlayed()
        state.reset()
        state.noteCueAudioPlayed()
        complete(state)

        XCTAssertEqual(try XCTUnwrap(recorder.records.first).cueAudioPlays, 1)
    }

    func testHintIsTheLevelReachedAtCompletion() {
        let (none, noneRecorder) = makeState(strokeCount: 1)
        complete(none)
        let (character, characterRecorder) = makeState(strokeCount: 1)
        character.showNextHint()
        complete(character)
        let (strokes, strokesRecorder) = makeState(strokeCount: 1)
        strokes.showNextHint()
        strokes.showNextHint()
        complete(strokes)
        let (practice, practiceRecorder) = makeState(strokeCount: 1, isRecall: false)
        complete(practice)

        XCTAssertEqual(noneRecorder.records.first?.hint, "none")
        XCTAssertEqual(characterRecorder.records.first?.hint, "character")
        XCTAssertEqual(strokesRecorder.records.first?.hint, "strokes")
        XCTAssertEqual(practiceRecorder.records.first?.hint, "none")
    }

    func testUndosCountOnlySuccessfulUndos() {
        let (state, recorder) = makeState(strokeCount: 2)
        XCTAssertNil(state.undoLastStroke())
        submit(state, matchedIndex: 0)
        XCTAssertEqual(state.undoLastStroke(), 0)
        submit(state, matchedIndex: 0)
        XCTAssertEqual(state.undoLastStroke(), 0)
        complete(state)

        XCTAssertEqual(recorder.records.first?.undos, 2)
    }

    func testResetStartsTheUndoCountAgain() {
        let (state, recorder) = makeState(strokeCount: 1)
        submit(state, matchedIndex: 0)
        XCTAssertEqual(state.undoLastStroke(), 0)
        state.reset()
        complete(state)

        XCTAssertEqual(recorder.records.first?.undos, 0)
    }

    func testInputSummarisesTheTouchTypesOfGradedStrokes() {
        XCTAssertEqual(input(of: [.finger, .finger]), "finger")
        XCTAssertEqual(input(of: [.pencil, .pencil]), "pencil")
        XCTAssertEqual(input(of: [.other]), "other")
        XCTAssertEqual(input(of: [.finger, .pencil]), "mixed")
        XCTAssertEqual(input(of: [.pencil, .other, .pencil]), "mixed")
        XCTAssertEqual(input(of: [.pencil, nil]), "pencil")
        XCTAssertNil(input(of: [nil, nil]))
    }

    func testPencilTakingOverAFingerStrokeCountsOnlyThePencil() {
        let (state, recorder) = makeState(strokeCount: 1)
        state.noteStrokeBegan(.finger)
        state.noteStrokeBegan(.pencil)
        submit(state, matchedIndex: 0)

        XCTAssertEqual(recorder.records.first?.input, "pencil")
    }

    func testTouchThatNeverReachesGradingIsNotCounted() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        state.noteStrokeBegan(.finger)
        state.reset()
        submit(state, matchedIndex: 0)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertNil(record.input)
        XCTAssertNil(record.firstTouchAt)
    }

    func testFirstTouchIsTheTouchDownOfTheFirstGradedStroke() throws {
        let (state, recorder) = makeState(strokeCount: 2)
        let shown = Date(timeIntervalSince1970: 1_000)
        let palm = Date(timeIntervalSince1970: 1_002)
        let touch = Date(timeIntervalSince1970: 1_003)
        let graded = Date(timeIntervalSince1970: 1_004)
        let later = Date(timeIntervalSince1970: 1_010)
        state.now = { shown }
        state.noteCueShown()
        state.now = { palm }
        state.noteStrokeBegan(.finger)
        state.now = { touch }
        state.noteStrokeBegan(.pencil)
        state.now = { graded }
        submit(state, matchedIndex: 0)
        state.now = { later }
        state.noteStrokeBegan(.pencil)
        submit(state, matchedIndex: 1)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.shownAt, shown)
        XCTAssertEqual(record.firstTouchAt, touch)
        XCTAssertEqual(record.startedAt, graded)
        XCTAssertEqual(record.completedAt, later)
        XCTAssertEqual(record.input, "pencil")
    }

    func testShownAtIsTheFirstAppearanceAndResetRestartsIt() {
        let (state, recorder) = makeState(strokeCount: 1)
        let first = Date(timeIntervalSince1970: 2_000)
        let again = Date(timeIntervalSince1970: 2_005)
        let restarted = Date(timeIntervalSince1970: 2_030)
        state.now = { first }
        state.noteCueShown()
        state.now = { again }
        state.noteCueShown()
        complete(state)
        state.now = { restarted }
        state.reset()
        state.now = { again }
        state.noteCueShown()
        complete(state)

        XCTAssertEqual(recorder.records.map(\.shownAt), [first, restarted])
    }

    func testModeChangeRestartsShownAt() {
        let (state, recorder) = makeState(strokeCount: 1, isRecall: false)
        let changed = Date(timeIntervalSince1970: 3_000)
        state.noteCueShown()
        state.now = { changed }
        state.changeMode(.copy)
        complete(state)

        XCTAssertEqual(recorder.records.first?.shownAt, changed)
    }

    func testCanvasSizeComesFromTheFirstGradedAttempt() throws {
        let (state, recorder) = makeState(strokeCount: 2)
        let size = CGSize(width: 343, height: 340)
        submit(state, matchedIndex: nil, canvasSize: size)
        submit(state, matchedIndex: 0, canvasSize: size)
        submit(state, matchedIndex: 1, canvasSize: size)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.canvasWidth, 343)
        XCTAssertEqual(record.canvasHeight, 340)
        XCTAssertEqual(record.configChanged, false)
    }

    func testCanvasResizeBetweenAttemptsMarksTheRun() {
        let (state, recorder) = makeState(strokeCount: 2)
        submit(state, matchedIndex: 0, canvasSize: CGSize(width: 343, height: 343))
        submit(state, matchedIndex: 1, canvasSize: CGSize(width: 600, height: 600))
        state.reset()
        submit(state, matchedIndex: 0, canvasSize: CGSize(width: 600, height: 600))
        submit(state, matchedIndex: 1, canvasSize: CGSize(width: 600, height: 600))

        XCTAssertEqual(recorder.records.map(\.configChanged), [true, false])
        XCTAssertEqual(recorder.records.map(\.canvasWidth), [343, 600])
    }

    func testConfigChangeBetweenAttemptsLatchesForTheRun() {
        let (state, recorder) = makeState(strokeCount: 3)
        submit(state, matchedIndex: 0)
        state.validationConfig = strictConfig
        submit(state, matchedIndex: 1)
        state.validationConfig = .standard
        submit(state, matchedIndex: 2)

        XCTAssertEqual(recorder.records.first?.configChanged, true)
    }

    func testConfigSetBeforeTheFirstAttemptIsNotAChange() {
        let (state, recorder) = makeState(strokeCount: 2)
        state.validationConfig = strictConfig
        complete(state)

        XCTAssertEqual(recorder.records.first?.configChanged, false)
        XCTAssertEqual(recorder.records.first?.strictness, GradingStrictness.strict.rawValue)
    }

    func testReassigningTheSameConfigIsNotAChange() {
        let (state, recorder) = makeState(strokeCount: 2)
        submit(state, matchedIndex: 0)
        state.validationConfig = .standard
        submit(state, matchedIndex: 1)

        XCTAssertEqual(recorder.records.first?.configChanged, false)
    }

    func testResetStartsARunWithoutAConfigChange() {
        let (state, recorder) = makeState(strokeCount: 2)
        submit(state, matchedIndex: 0)
        state.validationConfig = strictConfig
        submit(state, matchedIndex: 1)
        state.reset()
        complete(state)

        XCTAssertEqual(recorder.records.map(\.configChanged), [true, false])
    }

    func testLeavingTheSceneMidRunMarksItInterrupted() {
        let (state, recorder) = makeState(strokeCount: 2)
        state.noteCueShown()
        submit(state, matchedIndex: 0)
        state.noteSceneLeftActive()
        submit(state, matchedIndex: 1)
        state.reset()
        complete(state)

        XCTAssertEqual(recorder.records.map(\.interrupted), [true, false])
    }

    func testLeavingTheSceneBeforeTheCueIsShownIsIgnored() {
        let (state, recorder) = makeState(strokeCount: 1)
        state.noteSceneLeftActive()
        state.noteCueShown()
        complete(state)

        XCTAssertEqual(recorder.records.map(\.interrupted), [false])
    }

    func testIdiomAndAppVersionCanBeInjected() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        state.idiom = "pad"
        state.appVersion = "2.0 (77)"
        complete(state)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.idiom, "pad")
        XCTAssertEqual(record.appVersion, "2.0 (77)")
    }

    func testDefaultIdiomAndAppVersionDescribeTheRunningApp() throws {
        let state = PracticeState(kanjiData: makeKanjiData(strokeCount: 1))
        let info = Bundle.main.infoDictionary
        let version = try XCTUnwrap(info?["CFBundleShortVersionString"] as? String)
        let build = try XCTUnwrap(info?["CFBundleVersion"] as? String)

        XCTAssertEqual(state.idiom, UIDevice.current.userInterfaceIdiom == .pad ? "pad" : "phone")
        XCTAssertEqual(state.appVersion, "\(version) (\(build))")
    }

    func testStrokeStatsHaveOneEntryPerReferenceStroke() throws {
        let (state, recorder) = makeState(strokeCount: 3)
        complete(state)

        let strokes = try XCTUnwrap(recorder.records.first?.strokes)
        XCTAssertEqual(strokes.count, 3)
        XCTAssertEqual(strokes.map(\.attempts), [1, 1, 1])
        XCTAssertEqual(strokes.map(\.evidence), [MissEvidence(), MissEvidence(), MissEvidence()])
    }

    func testUndoneAcceptanceStillCountsAsAnAttempt() throws {
        let (state, recorder) = makeState(strokeCount: 2)
        submit(state, matchedIndex: 0)
        XCTAssertEqual(state.undoLastStroke(), 0)
        submit(state, matchedIndex: nil)
        submit(state, matchedIndex: 0)
        submit(state, matchedIndex: 1)

        let record = try XCTUnwrap(recorder.records.first)
        let strokes = try XCTUnwrap(record.strokes)
        XCTAssertEqual(strokes.map(\.attempts), [3, 1])
        XCTAssertEqual(strokes.map(\.undone), [1, 0])
        XCTAssertEqual(strokes.map(\.evidence.notEvaluated), [1, 0])
        XCTAssertEqual(record.undos, 1)
        XCTAssertEqual(record.misses, 1)
    }

    func testDisputeIsCountedOnTheRejectedStroke() throws {
        let (state, recorder) = makeState(strokeCount: 3)
        submit(state, matchedIndex: 0)
        reject(state, evidence: StrokeEvidence(shapePassed: false))
        state.disputeLastRejection()
        state.disputeLastRejection()
        complete(state)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.strokes?.map(\.evidence.disputed), [0, 1, 0])
        XCTAssertEqual(record.strokes?.map(\.evidence.shape), [0, 1, 0])
        XCTAssertEqual(record.evidence?.disputed, 1)
    }

    func testDrawnInsteadListsEachLaterStrokeOnceInAscendingOrder() throws {
        let (state, recorder) = makeState(strokeCount: 4)
        rejectOutOfOrder(state, drawn: 3)
        rejectOutOfOrder(state, drawn: 1)
        rejectOutOfOrder(state, drawn: 3)
        process(state, StrokeValidationResult(
            score: 0.3,
            accepted: false,
            matchedStrokeIndex: 2,
            correctOrder: false,
            frechetDistance: 0.5
        ))
        complete(state)

        let first = try XCTUnwrap(recorder.records.first?.strokes?.first)
        XCTAssertEqual(first.drawnInstead, [1, 3])
        XCTAssertEqual(first.evidence.order, 3)
        XCTAssertEqual(first.evidence.notEvaluated, 1)
        XCTAssertEqual(first.attempts, 5)
    }

    func testStrokeHintsKeepTheFirstAttemptAndTheLatestAcceptance() throws {
        let (state, recorder) = makeState(strokeCount: 2)
        submit(state, matchedIndex: nil)
        submit(state, matchedIndex: 0)
        XCTAssertEqual(state.undoLastStroke(), 0)
        state.showNextHint()
        submit(state, matchedIndex: 0)
        state.showNextHint()
        submit(state, matchedIndex: 1)

        let strokes = try XCTUnwrap(recorder.records.first?.strokes)
        XCTAssertEqual(strokes.map(\.firstHint), ["none", "strokes"])
        XCTAssertEqual(strokes.map(\.acceptedHint), ["character", "strokes"])
    }

    func testStrokeHintsAreLeftOutOutsideRecall() throws {
        let (state, recorder) = makeState(strokeCount: 2, mode: .copy, isRecall: false)
        submit(state, matchedIndex: nil)
        complete(state)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.hint, "none")
        let strokes = try XCTUnwrap(record.strokes)
        XCTAssertEqual(strokes.map(\.attempts), [2, 1])
        XCTAssertEqual(strokes.map(\.firstHint), [nil, nil])
        XCTAssertEqual(strokes.map(\.acceptedHint), [nil, nil])
    }

    func testFirstTouchDelayKeepsMilliseconds() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        let shown = Date(timeIntervalSince1970: 1_000)
        state.now = { shown }
        state.noteCueShown()
        state.now = { shown.addingTimeInterval(1.234) }
        state.noteStrokeBegan(.finger)
        submit(state, matchedIndex: 0)

        XCTAssertEqual(recorder.records.first?.firstTouchDelayMs, 1234)
    }

    func testFirstTouchDelayNeedsBothTimes() throws {
        let (state, recorder) = makeState(strokeCount: 1)
        state.noteStrokeBegan(.finger)
        submit(state, matchedIndex: 0)

        XCTAssertNil(recorder.records.first?.shownAt)
        XCTAssertNil(recorder.records.first?.firstTouchDelayMs)
    }

    func testStrokeEvidenceAddsUpToTheRunEvidence() throws {
        let (state, recorder) = makeState(strokeCount: 3)
        reject(state, evidence: StrokeEvidence(shapePassed: false, positionPassed: false))
        rejectOutOfOrder(state, drawn: 2)
        state.disputeLastRejection()
        submit(state, matchedIndex: 0)
        rejectOutOfFrame(state)
        reject(state, evidence: .notEvaluated)
        state.disputeLastRejection()
        submit(state, matchedIndex: 1)
        XCTAssertEqual(state.undoLastStroke(), 1)
        reject(state, evidence: StrokeEvidence(shapePassed: true, positionPassed: true, proportionPassed: false))
        submit(state, matchedIndex: 1)
        submit(state, matchedIndex: 2)

        let record = try XCTUnwrap(recorder.records.first)
        let strokes = try XCTUnwrap(record.strokes)
        XCTAssertEqual(total(of: strokes), record.evidence)
        XCTAssertEqual(
            record.evidence,
            MissEvidence(shape: 1, position: 1, proportion: 1, order: 1, notEvaluated: 1, disputed: 2, boundary: 1)
        )
        XCTAssertEqual(strokes.map(\.attempts).reduce(0, +), record.misses + 4)
        XCTAssertEqual(strokes.map(\.drawnInstead), [[2], [], []])
    }

    func testRecordIsFrozenAtTheFirstCompletion() throws {
        let (state, recorder) = makeState(strokeCount: 2)
        complete(state)
        let emitted = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(state.undoLastStroke(), 1)
        submit(state, matchedIndex: nil)
        submit(state, matchedIndex: 1)

        XCTAssertEqual(recorder.records, [emitted])
        XCTAssertEqual(emitted.strokes?.map(\.attempts), [1, 1])
        XCTAssertEqual(emitted.undos, 0)
    }
}

@MainActor
private final class Recorder {
    var records: [PracticeRecord] = []
}
