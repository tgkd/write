import XCTest
@testable import Write

@MainActor
final class SentencePracticeStateTests: XCTestCase {

    private var historyDirectory: URL!

    override func setUp() async throws {
        historyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SentencePracticeStateTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: historyDirectory)
    }

    private let characters: [Character: KanjiData] = [
        "庭": SentencePracticeStateTests.kanjiData("5ead", strokes: 2),
        "の": SentencePracticeStateTests.kanjiData("306e", strokes: 1),
        "花": SentencePracticeStateTests.kanjiData("82b1", strokes: 3),
        "は": SentencePracticeStateTests.kanjiData("306f", strokes: 2),
        "水": SentencePracticeStateTests.kanjiData("6c34", strokes: 2),
        "が": SentencePracticeStateTests.kanjiData("304c", strokes: 1),
    ]

    private static func kanjiData(_ codePoint: String, strokes: Int) -> KanjiData {
        KanjiData(
            codePoint: codePoint,
            element: nil,
            strokes: (1...strokes).map { KanjiStroke(strokeNumber: $0, pathData: "M10,10 L50,50", strokeType: nil) },
            components: []
        )
    }

    private let garden = WordPrompt(
        id: "s-garden",
        before: "にわの ",
        reading: "はな",
        after: "は。",
        gloss: "flower",
        segments: [.kanji("花")],
        notes: "",
        translation: "The garden's flowers.",
        tokens: [
            SentenceToken(surface: "庭", reading: "にわ"),
            SentenceToken(surface: "の", reading: nil),
            SentenceToken(surface: "花", reading: "はな"),
            SentenceToken(surface: "は", reading: nil),
            SentenceToken(surface: "。", reading: nil),
        ]
    )

    private let water = WordPrompt(
        id: "s-water",
        before: "",
        reading: "みず",
        after: "が",
        gloss: "water",
        segments: [.kanji("水")],
        notes: "",
        translation: "Water.",
        tokens: [
            SentenceToken(surface: "水", reading: "みず"),
            SentenceToken(surface: "が", reading: nil),
        ]
    )

    private let noTokens = WordPrompt(
        id: "s-none",
        before: "",
        reading: "みず",
        after: "",
        gloss: "water",
        segments: [.kanji("水")],
        notes: ""
    )

    private let onlyPunctuation = WordPrompt(
        id: "s-punct",
        before: "",
        reading: "",
        after: "",
        gloss: "",
        segments: [],
        notes: "",
        translation: "",
        tokens: [SentenceToken(surface: "。", reading: nil)]
    )

    private func makeState(_ prompts: [WordPrompt]) -> (SentencePracticeState, SentenceRecorder) {
        let state = SentencePracticeState(prompts: prompts, lookup: { self.characters[$0] })
        let recorder = SentenceRecorder()
        state.onSentenceCompleted = { recorder.records.append($0) }
        return (state, recorder)
    }

    private func submit(_ slot: PracticeState, matchedIndex: Int?) {
        slot.beginDrawing()
        slot.beginValidation()
        slot.processValidationResult(StrokeValidationResult(
            score: matchedIndex == nil ? 0.1 : 0.9,
            accepted: matchedIndex != nil,
            matchedStrokeIndex: matchedIndex,
            correctOrder: true,
            frechetDistance: 0.1
        ))
        slot.acknowledgeResult()
    }

    private func completeCell(_ state: SentencePracticeState, misses: Int = 0) {
        guard let slot = state.slotState else {
            XCTFail("no slot")
            return
        }
        for _ in 0..<misses {
            submit(slot, matchedIndex: nil)
        }
        for index in 0..<slot.totalStrokes {
            submit(slot, matchedIndex: index)
        }
    }

    private func completeSentence(_ state: SentencePracticeState) {
        let count = state.currentItem?.writable.count ?? 0
        for _ in 0..<count {
            completeCell(state)
        }
    }

    func testBuildsOneBlockPerTokenAndOneCellPerCharacter() throws {
        let (state, _) = makeState([garden])
        let item = try XCTUnwrap(state.currentItem)

        XCTAssertEqual(item.blocks.count, 5)
        XCTAssertEqual(item.cells.map(\.characterIndex), [0, 1, 2, 3, 4])
        XCTAssertEqual(item.cells.map(\.character), ["庭", "の", "花", "は", "。"])
        XCTAssertEqual(item.writtenSentence, "庭の花は。")
        XCTAssertEqual(item.kanaSentence, "にわ の はな は。")
        XCTAssertTrue(item.blocks[4].isPunctuation)
        XCTAssertFalse(item.blocks[1].isPunctuation)
    }

    func testPunctuationIsFilledInAutomaticallyAndNeverWritten() throws {
        let (state, _) = makeState([garden])
        let item = try XCTUnwrap(state.currentItem)

        XCTAssertEqual(item.writable.map(\.characterIndex), [0, 1, 2, 3])
        XCTAssertFalse(item.cells[4].isWritten)
        XCTAssertEqual(state.completedCharacterIndices, [4])
        XCTAssertEqual(state.currentCharacterIndex, 0)
    }

    func testCursorWalksCellsInOrderAcrossBlocks() {
        let (state, _) = makeState([garden])
        var visited: [Int] = []
        var codePoints: [String] = []
        while let index = state.currentCharacterIndex {
            visited.append(index)
            codePoints.append(state.slotState?.kanjiData.codePoint ?? "")
            XCTAssertTrue(state.slotState?.isRecall ?? false)
            completeCell(state)
        }

        XCTAssertEqual(visited, [0, 1, 2, 3])
        XCTAssertEqual(codePoints, ["5ead", "306e", "82b1", "306f"])
        XCTAssertTrue(state.isSentenceComplete)
        XCTAssertEqual(state.completedCharacterIndices, [0, 1, 2, 3, 4])
    }

    func testCompletingASentenceEmitsExactlyOneRecord() throws {
        let (state, recorder) = makeState([garden, water])
        completeCell(state, misses: 1)
        completeCell(state)
        completeCell(state, misses: 2)
        XCTAssertTrue(recorder.records.isEmpty)
        completeCell(state)

        XCTAssertEqual(recorder.records.count, 1)
        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.promptID, "s-garden")
        XCTAssertEqual(record.slotCount, 4)
        XCTAssertEqual(record.misses, 3)
        XCTAssertEqual(record.hintsUsed, 0)
        XCTAssertEqual(record.cue, "kana-sentence+en-translation/blocks")
        XCTAssertEqual(record.sessionID, state.sessionID)
        XCTAssertEqual(record.promptRevision, garden.revision)
        XCTAssertLessThanOrEqual(record.startedAt, record.completedAt)
        let slots = try XCTUnwrap(record.slots)
        XCTAssertEqual(slots.map(\.segmentIndex), [0, 1, 2, 3])
        XCTAssertEqual(slots.map(\.record.codePoint), ["5ead", "306e", "82b1", "306f"])
        XCTAssertEqual(slots.map(\.record.misses), [1, 0, 2, 0])

        state.advanceSentence()
        state.advanceSentence()
        XCTAssertEqual(recorder.records.count, 1)
        XCTAssertEqual(state.promptIndex, 1)
    }

    func testHintsCountRevealedCells() throws {
        let (state, recorder) = makeState([water])
        state.slotState?.showNextHint()
        completeCell(state)
        completeCell(state)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(record.hintsUsed, 1)
        XCTAssertEqual(state.results.first?.hintsUsed, 1)
    }

    func testRestartClearsProgressAndRecords() {
        let (state, recorder) = makeState([garden])
        let firstRun = state.slotRun
        completeCell(state)
        completeCell(state)
        XCTAssertEqual(state.cellIndex, 2)

        state.restartSentence()

        XCTAssertEqual(state.cellIndex, 0)
        XCTAssertEqual(state.currentCharacterIndex, 0)
        XCTAssertEqual(state.completedCharacterIndices, [4])
        XCTAssertGreaterThan(state.slotRun, firstRun + 2)
        XCTAssertEqual(state.slotState?.kanjiData.codePoint, "5ead")
        XCTAssertFalse(state.isSentenceComplete)

        completeSentence(state)
        let record = recorder.records.first
        XCTAssertEqual(recorder.records.count, 1)
        XCTAssertEqual(record?.slots?.count, 4)
    }

    func testRestartIsIgnoredAfterCompletion() {
        let (state, recorder) = makeState([garden])
        completeSentence(state)
        state.restartSentence()

        XCTAssertTrue(state.isSentenceComplete)
        XCTAssertEqual(recorder.records.count, 1)
    }

    func testAdvancingPastTheLastSentenceCompletesTheSession() {
        let (state, recorder) = makeState([garden, water])
        completeSentence(state)
        state.advanceSentence()
        XCTAssertTrue(state.isLastSentence)
        completeSentence(state)
        state.advanceSentence()

        XCTAssertTrue(state.isSessionComplete)
        XCTAssertNil(state.slotState)
        XCTAssertEqual(recorder.records.map(\.promptID), ["s-garden", "s-water"])
        XCTAssertEqual(state.results.map(\.sentence), ["庭の花は。", "水が"])
    }

    func testPromptsWithoutWritableCharactersAreSkipped() {
        let (state, _) = makeState([noTokens, onlyPunctuation, water])

        XCTAssertEqual(state.items.map(\.prompt.id), ["s-water"])
        XCTAssertFalse(state.isSessionComplete)

        let (empty, _) = makeState([noTokens])
        XCTAssertTrue(empty.isSessionComplete)
        XCTAssertNil(empty.slotState)
    }

    func testValidationConfigReachesTheCurrentAndNextCells() {
        let (state, _) = makeState([water])
        var config = ValidationConfig.standard
        config.leniency = 1.7
        state.validationConfig = config

        XCTAssertEqual(state.slotState?.validationConfig.leniency, 1.7)
        completeCell(state)
        XCTAssertEqual(state.slotState?.validationConfig.leniency, 1.7)
    }

    func testCellRunsNeverReachPracticeHistory() {
        let history = PracticeHistoryStore(directory: historyDirectory)
        let (state, recorder) = makeState([garden, water])
        completeSentence(state)
        state.advanceSentence()
        completeSentence(state)

        XCTAssertEqual(recorder.records.count, 2)
        XCTAssertEqual(recorder.records.flatMap { $0.slots ?? [] }.count, 6)
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertEqual(history.unsavedCount, 0)
        XCTAssertTrue(PracticeHistoryStore(directory: historyDirectory).records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: historyDirectory.path))
    }
}

private final class SentenceRecorder {
    var records: [WordRecord] = []
}
