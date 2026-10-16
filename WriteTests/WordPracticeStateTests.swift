import XCTest
@testable import Write

@MainActor
final class WordPracticeStateTests: XCTestCase {

    private var historyDirectory: URL!

    override func setUp() async throws {
        historyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WordPracticeStateTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: historyDirectory)
    }

    private let kanji: [Character: KanjiData] = [
        "学": WordPracticeStateTests.kanjiData("5b66", strokes: 2),
        "校": WordPracticeStateTests.kanjiData("6821", strokes: 3),
        "大": WordPracticeStateTests.kanjiData("5927", strokes: 1),
    ]

    private static func kanjiData(_ codePoint: String, strokes: Int) -> KanjiData {
        KanjiData(
            codePoint: codePoint,
            element: nil,
            strokes: (1...strokes).map { KanjiStroke(strokeNumber: $0, pathData: "M10,10 L50,50", strokeType: nil) },
            components: []
        )
    }

    private let school = WordPrompt(
        id: "t-school",
        before: "まいあさ ",
        reading: "がっこう",
        after: "に いきます。",
        gloss: "school",
        segments: [.kanji("学"), .kanji("校")],
        notes: ""
    )

    private let big = WordPrompt(
        id: "t-big",
        before: "あの ",
        reading: "おおきい",
        after: " いぬ",
        gloss: "big",
        segments: [.kanji("大"), .kana("きい")],
        notes: ""
    )

    private let missing = WordPrompt(
        id: "t-missing",
        before: "",
        reading: "みず",
        after: "",
        gloss: "water",
        segments: [.kanji("水")],
        notes: ""
    )

    private func makeState(_ prompts: [WordPrompt]) -> (WordPracticeState, Recorder) {
        let state = WordPracticeState(prompts: prompts, lookup: { self.kanji[$0] })
        let recorder = Recorder()
        state.onWordCompleted = { recorder.records.append($0) }
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

    private func completeSlot(_ state: WordPracticeState, misses: Int = 0) {
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

    func testTwoSlotWordCompletesAfterBothSlotsAndRecordsOnce() throws {
        let (state, recorder) = makeState([school, big])

        XCTAssertEqual(state.currentSlotID, "t-school-0")
        XCTAssertEqual(state.slotState?.kanjiData.codePoint, "5b66")
        XCTAssertTrue(state.slotState?.isRecall ?? false)
        XCTAssertTrue(state.slotState?.hidesCharacter ?? false)
        XCTAssertTrue(state.slotState?.hidesGuide ?? false)

        completeSlot(state, misses: 1)
        XCTAssertFalse(state.isWordComplete)
        XCTAssertTrue(recorder.records.isEmpty)
        XCTAssertEqual(state.slotIndex, 1)
        XCTAssertEqual(state.currentSlotID, "t-school-1")
        XCTAssertEqual(state.slotState?.kanjiData.codePoint, "6821")
        XCTAssertEqual(state.completedSegmentIndices, [0])

        completeSlot(state, misses: 2)
        XCTAssertTrue(state.isWordComplete)
        XCTAssertEqual(state.completedSegmentIndices, [0, 1])
        XCTAssertNil(state.currentSegmentIndex)

        let record = try XCTUnwrap(recorder.records.first)
        XCTAssertEqual(recorder.records.count, 1)
        XCTAssertEqual(record.promptID, "t-school")
        XCTAssertEqual(record.misses, 3)
        XCTAssertEqual(record.hintsUsed, 0)
        XCTAssertEqual(record.slotCount, 2)
        XCTAssertLessThanOrEqual(record.startedAt, record.completedAt)
        XCTAssertEqual(state.results.map(\.prompt.id), ["t-school"])
    }

    func testAdvanceWordMovesToNextPromptThenCompletesSession() {
        let (state, recorder) = makeState([school, big])
        completeSlot(state)
        completeSlot(state)
        state.advanceWord()

        XCTAssertEqual(state.promptIndex, 1)
        XCTAssertEqual(state.slotIndex, 0)
        XCTAssertFalse(state.isWordComplete)
        XCTAssertEqual(state.currentSlotID, "t-big-0")
        XCTAssertEqual(state.progress.current, 2)

        completeSlot(state)
        XCTAssertTrue(state.isWordComplete)
        state.advanceWord()

        XCTAssertTrue(state.isSessionComplete)
        XCTAssertEqual(recorder.records.map(\.promptID), ["t-school", "t-big"])
        XCTAssertEqual(recorder.records.last?.slotCount, 1)
    }

    func testAdvanceWordIsIgnoredBeforeTheWordIsComplete() {
        let (state, _) = makeState([school, big])
        completeSlot(state)
        state.advanceWord()

        XCTAssertEqual(state.promptIndex, 0)
        XCTAssertEqual(state.slotIndex, 1)
    }

    func testResetWordRestartsFromFirstSlotWithoutRecord() {
        let (state, recorder) = makeState([school])
        completeSlot(state, misses: 4)
        let secondSlot = state.slotState
        state.resetWord()

        XCTAssertEqual(state.slotIndex, 0)
        XCTAssertEqual(state.currentSlotID, "t-school-0")
        XCTAssertFalse(state.slotState === secondSlot)
        XCTAssertEqual(state.slotRun, 3)
        XCTAssertEqual(state.slotState?.matchedStrokeIndices, [])
        XCTAssertTrue(recorder.records.isEmpty)
        XCTAssertEqual(state.completedSegmentIndices, [])

        completeSlot(state)
        completeSlot(state)
        XCTAssertEqual(recorder.records.count, 1)
        XCTAssertEqual(recorder.records.first?.misses, 0)
    }

    func testResetIsIgnoredAfterTheWordIsRecorded() {
        let (state, recorder) = makeState([big])
        completeSlot(state)
        state.resetWord()

        XCTAssertTrue(state.isWordComplete)
        XCTAssertEqual(recorder.records.count, 1)
    }

    func testHintsAreCountedPerSlot() {
        let (state, recorder) = makeState([school])
        state.slotState?.showNextHint()
        state.slotState?.showNextHint()
        completeSlot(state)
        completeSlot(state)

        XCTAssertEqual(recorder.records.first?.hintsUsed, 1)
        XCTAssertEqual(state.wordsNeedingHints, 1)
    }

    func testHintInEverySlotCountsEverySlot() {
        let (state, recorder) = makeState([school])
        state.slotState?.showNextHint()
        completeSlot(state)
        state.slotState?.showNextHint()
        completeSlot(state)

        XCTAssertEqual(recorder.records.first?.hintsUsed, 2)
    }

    func testOldSlotCompletionIsIgnored() {
        let (state, recorder) = makeState([school])
        let stale = state.slotState
        state.resetWord()
        if let stale {
            for index in 0..<stale.totalStrokes {
                submit(stale, matchedIndex: index)
            }
        }

        XCTAssertEqual(state.slotIndex, 0)
        XCTAssertTrue(recorder.records.isEmpty)
    }

    func testPromptsWithMissingKanjiAreSkipped() {
        let (state, _) = makeState([missing, big])

        XCTAssertEqual(state.items.map(\.prompt.id), ["t-big"])
        XCTAssertEqual(state.currentPrompt?.id, "t-big")
    }

    func testOnlyMissingPromptsCompleteTheSessionImmediately() {
        let (state, _) = makeState([missing])

        XCTAssertTrue(state.isSessionComplete)
        XCTAssertNil(state.slotState)
    }

    func testValidationConfigReachesCurrentAndNextSlots() {
        let (state, _) = makeState([school])
        var config = ValidationConfig.standard
        config.leniency = 1.7
        state.validationConfig = config

        XCTAssertEqual(state.slotState?.validationConfig.leniency, 1.7)
        completeSlot(state)
        XCTAssertEqual(state.slotState?.validationConfig.leniency, 1.7)
    }

    func testSlotRunsNeverReachPracticeHistory() {
        let history = PracticeHistoryStore(directory: historyDirectory)
        let (state, recorder) = makeState([school, big])
        completeSlot(state)
        completeSlot(state)
        state.advanceWord()
        completeSlot(state)

        XCTAssertEqual(recorder.records.count, 2)
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertEqual(history.unsavedCount, 0)
        XCTAssertTrue(PracticeHistoryStore(directory: historyDirectory).records.isEmpty)
    }
}

@MainActor
private final class Recorder {
    var records: [WordRecord] = []
}
