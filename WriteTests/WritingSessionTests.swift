import XCTest
@testable import Write

@MainActor
final class WritingSessionTests: XCTestCase {
    private func prompt(id: String = "test", safe: Bool = true) -> WordPrompt {
        WordPrompt(
            id: id, before: "", reading: "", after: "", gloss: "", segments: [], notes: "",
            translation: "A cat.",
            tokens: [SentenceToken(surface: "きゃ", reading: nil), SentenceToken(surface: "は", reading: nil),
                     SentenceToken(surface: "猫", reading: "ねこ"), SentenceToken(surface: "。", reading: nil)],
            presentation: SentencePresentation(version: 1, groups: [[0], [1, 2, 3]],
                emptyIssues: safe ? [] : [.init(tokenIndex: 2, reason: "common homophone")])
        )
    }

    private func lookup(_ character: Character) -> KanjiData? {
        guard !"ゃ。".contains(character) else {
            return nil
        }
        return KanjiData(codePoint: String(character.unicodeScalars.first!.value, radix: 16), element: nil,
                         strokes: [KanjiStroke(strokeNumber: 1, pathData: "M10,10 L80,80", strokeType: nil)], components: [])
    }

    private func complete(_ state: WritingSession, misses: Int = 0) throws {
        let slot = try XCTUnwrap(state.slotState)
        for _ in 0..<misses {
            slot.beginDrawing()
            slot.beginValidation()
            slot.processValidationResult(StrokeValidationResult(score: 0, accepted: false, matchedStrokeIndex: nil, correctOrder: false, frechetDistance: 1))
            slot.acknowledgeResult()
        }
        slot.beginDrawing()
        slot.beginValidation()
        slot.processValidationResult(StrokeValidationResult(score: 1, accepted: true, matchedStrokeIndex: 0, correctOrder: true, frechetDistance: 0), canvasSize: CGSize(width: 200, height: 200))
        slot.acknowledgeResult()
    }

    func testGroupsKeepCharacterIndicesAndPunctuationOutsideCells() throws {
        let state = WritingSession(prompts: [prompt()], lookup: lookup)
        let item = try XCTUnwrap(state.currentItem)
        XCTAssertEqual(item.sentence, "きゃは猫。")
        XCTAssertEqual(item.phrases.map(\.text), ["きゃ", "は猫。"])
        XCTAssertEqual(item.phrases.flatMap(\.cells).map(\.characterIndex), [0, 1, 2, 3])
        XCTAssertEqual(item.phrases.flatMap(\.writable).map(\.characterIndex), [0, 2, 3])
        XCTAssertEqual(item.phrases.flatMap(\.units).last?.characterIndex, 4)
    }

    func testFreeAdvancesWholeSentencesWithoutRecordsOrGrading() {
        let state = WritingSession(prompts: [prompt(), prompt(id: "second")], lookup: lookup)
        var records: [WordRecord] = []
        state.onSentenceCompleted = { records.append($0) }
        XCTAssertNil(state.slotState)
        XCTAssertNil(state.currentCell)
        XCTAssertFalse(state.isLastPrompt)
        state.advance()
        XCTAssertEqual(state.currentItem?.prompt.id, "second")
        XCTAssertFalse(state.isSentenceComplete)
        XCTAssertEqual(state.completedSentenceCount, 1)
        XCTAssertEqual(state.sentenceNumber, 2)
        XCTAssertTrue(state.isLastPrompt)
        state.advance()
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.completedSentenceCount, 2)
        XCTAssertTrue(records.isEmpty)
        XCTAssertTrue(state.results.isEmpty)
    }

    func testTraceMovesThroughWholeSentenceAndRecordsAreExposed() throws {
        let state = WritingSession(prompts: [prompt()], mode: .trace, lookup: lookup)
        var records: [WordRecord] = []
        state.onSentenceCompleted = { records.append($0) }
        state.advance()
        XCTAssertEqual(state.phraseIndex, 0)
        XCTAssertEqual(state.currentCell?.characterIndex, 0)
        try complete(state, misses: 1)
        XCTAssertEqual(state.phraseIndex, 1)
        XCTAssertEqual(state.currentCell?.characterIndex, 2)
        XCTAssertNotNil(state.slotState)
        try complete(state)
        XCTAssertEqual(state.currentCell?.characterIndex, 3)
        try complete(state)
        XCTAssertTrue(state.isSentenceComplete)
        XCTAssertNil(state.currentCell)
        XCTAssertNil(state.slotState)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.slotCount, 3)
        XCTAssertEqual(record.misses, 1)
        XCTAssertEqual(record.cue, "kana-sentence+en-translation/phrases-v1/trace")
        XCTAssertEqual(record.promptRevision, prompt().revision)
        XCTAssertEqual(record.slots?.map(\.segmentIndex), [0, 2, 3])
        XCTAssertTrue(record.slots?.allSatisfy { $0.record.exposed && $0.record.mode == PracticeMode.trace.rawValue } == true)
        state.advance()
        XCTAssertTrue(state.isComplete)
        state.advance()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(state.results.count, 1)
    }

    func testEmptyUsesRecallAndHintsInNestedRecords() throws {
        let state = WritingSession(prompts: [prompt()], mode: .empty, lookup: lookup)
        var record: WordRecord?
        state.onSentenceCompleted = { record = $0 }
        XCTAssertTrue(state.slotState?.hidesGuide == true)
        state.slotState?.showNextHint()
        try complete(state)
        try complete(state)
        try complete(state)
        XCTAssertEqual(record?.hintsUsed, 1)
        XCTAssertTrue(record?.slots?.allSatisfy { !$0.record.exposed && $0.record.mode == PracticeRecord.recallMode } == true)
        XCTAssertEqual(record?.cue, "kana-sentence+en-translation/phrases-v1/empty")
    }

    func testRestartKeepsEarlierPhraseRecordsAndDiscardsCurrentPhraseAttempts() throws {
        let state = WritingSession(prompts: [prompt()], mode: .trace, lookup: lookup)
        var record: WordRecord?
        state.onSentenceCompleted = { record = $0 }
        try complete(state, misses: 1)
        try complete(state, misses: 4)
        XCTAssertEqual(state.currentCell?.characterIndex, 3)
        let cleared = state.restartPhrase()
        XCTAssertEqual(cleared.map(\.id), ["0.2", "0.3", "0.4"])
        XCTAssertEqual(state.currentCell?.characterIndex, 2)
        XCTAssertEqual(state.completedCellIDs, ["0.0"])
        try complete(state)
        try complete(state)
        XCTAssertEqual(record?.misses, 1)
        XCTAssertEqual(record?.slots?.map(\.segmentIndex), [0, 2, 3])
    }

    func testModeAppliesOnFirstPhraseRestartOtherwiseAtNextSentence() throws {
        let state = WritingSession(prompts: [prompt(), prompt(id: "second")], mode: .trace, lookup: lookup)
        state.requestedMode = .empty
        XCTAssertFalse(state.slotState?.isRecall ?? true)
        state.restartPhrase()
        XCTAssertEqual(state.activeMode, .empty)
        XCTAssertTrue(state.slotState?.isRecall == true)
        state.requestedMode = .trace
        try complete(state)
        XCTAssertEqual(state.phraseIndex, 1)
        state.restartPhrase()
        XCTAssertEqual(state.activeMode, .empty)
        XCTAssertTrue(state.slotState?.isRecall == true)
        XCTAssertEqual(state.currentCell?.characterIndex, 2)
        try complete(state)
        try complete(state)
        XCTAssertTrue(state.isSentenceComplete)
        state.advance()
        XCTAssertEqual(state.activeMode, .trace)
        XCTAssertFalse(state.slotState?.isRecall ?? true)
    }

    func testFreeRestartClearsWholeSentenceAndAppliesAllowedQueuedMode() {
        let state = WritingSession(prompts: [prompt()], lookup: lookup)
        state.requestedMode = .trace
        let cleared = state.restartPhrase()
        XCTAssertEqual(cleared.map(\.characterIndex), [0, 1, 2, 3, 4])
        XCTAssertEqual(state.activeMode, .trace)
        XCTAssertEqual(state.currentCell?.characterIndex, 0)
        XCTAssertNotNil(state.slotState)

        let unsafe = WritingSession(prompts: [prompt(safe: false)], lookup: lookup)
        unsafe.requestedMode = .empty
        XCTAssertEqual(unsafe.restartPhrase().count, 5)
        XCTAssertEqual(unsafe.activeMode, .free)
        XCTAssertNil(unsafe.slotState)
    }

    func testEmptyExcludesFlaggedAndUnreviewedPrompts() {
        var unreviewed = prompt(id: "unreviewed")
        unreviewed.presentation?.emptyIssues = nil
        let state = WritingSession(prompts: [prompt(id: "unsafe", safe: false), unreviewed, prompt(id: "safe")], mode: .empty, lookup: lookup)
        XCTAssertEqual(state.currentItem?.prompt.id, "safe")
        XCTAssertTrue(WritingSession(prompts: [unreviewed], mode: .empty, lookup: lookup).isComplete)
        XCTAssertFalse(WritingSession(prompts: [unreviewed], mode: .trace, lookup: lookup).isComplete)
    }

    func testLegacyDecodeRevisionAndInvalidGroups() throws {
        var legacy = prompt()
        legacy.presentation = nil
        let decoded = try JSONDecoder().decode(WordPrompt.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(decoded.presentation)
        XCTAssertEqual(decoded.revision, prompt().revision)
        for groups in [[[0], [1, 2]], [[0, 1], [1, 2, 3]], [[0], [], [1, 2, 3]], [[1, 0], [2, 3]]] {
            var invalid = prompt()
            invalid.presentation = SentencePresentation(version: 1, groups: groups)
            XCTAssertTrue(WritingSession(prompts: [invalid], lookup: lookup).isComplete)
        }
        XCTAssertTrue(WritingSession(prompts: [], lookup: lookup).isComplete)
    }

    func testCounterCountsCompletedAndEligibleSentencesWithoutIndexJumps() throws {
        let state = WritingSession(prompts: [prompt(id: "first", safe: false), prompt(id: "second"),
                                             prompt(id: "skipped", safe: false), prompt(id: "last")], mode: .trace, lookup: lookup)
        XCTAssertEqual(state.sentenceNumber, 1)
        XCTAssertEqual(state.totalSentenceCount, 4)
        state.requestedMode = .empty
        XCTAssertEqual(state.activeMode, .trace)
        XCTAssertEqual(state.totalSentenceCount, 3)
        for expected in 1...3 {
            XCTAssertEqual(state.sentenceNumber, expected)
            try complete(state)
            try complete(state)
            try complete(state)
            XCTAssertTrue(state.isSentenceComplete)
            XCTAssertEqual(state.sentenceNumber, expected)
            state.advance()
        }
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.completedSentenceCount, 3)
        XCTAssertEqual(state.results.map(\.prompt.id), ["first", "second", "last"])
    }

    func testQueuedEmptyWithNoEligibleRemainderFinishesOnlyAfterCurrentSentence() {
        let state = WritingSession(prompts: [prompt(id: "current", safe: false), prompt(id: "excluded", safe: false)], lookup: lookup)
        state.requestedMode = .empty
        XCTAssertTrue(state.endsBeforeQueuedEmpty)
        XCTAssertEqual(state.sentenceNumber, 1)
        XCTAssertEqual(state.totalSentenceCount, 1)
        XCTAssertFalse(state.isComplete)
        XCTAssertFalse(state.isSentenceComplete)
        XCTAssertTrue(state.isLastPrompt)
        state.advance()
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.completedSentenceCount, 1)
        XCTAssertEqual(state.sentenceNumber, 1)
        XCTAssertTrue(state.results.isEmpty)
    }
}
