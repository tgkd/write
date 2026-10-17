import XCTest
@testable import Write

@MainActor
final class PracticeStatsSchemaTests: XCTestCase {
    private struct HistoryFile<Record: Encodable>: Encodable {
        let version: Int
        let records: [Record]
    }

    private var directory: URL!
    private let utc = TimeZone(identifier: "UTC")!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PracticeStatsSchemaTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func storeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private func encodedString<Value: Encodable>(_ value: Value) throws -> String {
        String(decoding: try storeEncoder().encode(value), as: UTF8.self)
    }

    private func strokeStats(count: Int) -> [StrokeStat] {
        (0..<count).map { index in
            let hint = index < count / 2 ? "none" : "character"
            var stat = StrokeStat(attempts: 1, firstHint: hint, acceptedHint: hint)
            if index == 0 {
                stat.attempts = 2
                stat.evidence = MissEvidence(shape: 1)
            }
            if index == 2 {
                stat.attempts = 2
                stat.evidence = MissEvidence(order: 1)
                stat.drawnInstead = [5]
            }
            if index == 4 {
                stat.attempts = 2
                stat.evidence = MissEvidence(shape: 1, disputed: 1)
            }
            if index == 7 {
                stat.attempts = 2
                stat.undone = 1
            }
            return stat
        }
    }

    private func richRecord(
        completedAt: Date,
        strokeCount: Int = 10,
        sessionID: UUID = UUID(),
        slot: Int = 4,
        origin: RunOrigin? = .randomSession
    ) -> PracticeRecord {
        PracticeRecord(
            id: UUID(),
            codePoint: "6821",
            mode: PracticeRecord.recallMode,
            revealed: true,
            exposed: false,
            misses: 3,
            startedAt: completedAt.addingTimeInterval(-42),
            completedAt: completedAt,
            leniency: 1.2649110640673518,
            strictness: GradingStrictness.normal.rawValue,
            gradingVersion: ValidationConfig.gradingVersion,
            evidence: MissEvidence(shape: 2, order: 1, disputed: 1),
            sessionID: sessionID,
            slot: slot,
            origin: origin?.rawValue,
            hint: RecallHint.character.recordName,
            undos: 1,
            input: InputKind.finger.rawValue,
            canvasWidth: 361,
            canvasHeight: 361,
            idiom: "phone",
            appVersion: "1.9 (56)",
            shownAt: completedAt.addingTimeInterval(-50),
            firstTouchAt: completedAt.addingTimeInterval(-44),
            interrupted: false,
            configChanged: false,
            strokes: strokeStats(count: strokeCount)
        )
    }

    private func wordRecord(completedAt: Date) -> WordRecord {
        let session = UUID()
        let slots = [0, 1].map { segment in
            WordSlotRecord(
                segmentIndex: segment,
                record: richRecord(
                    completedAt: completedAt.addingTimeInterval(Double(segment - 1) * 30),
                    sessionID: session,
                    slot: 0,
                    origin: nil
                )
            )
        }
        return WordRecord(
            id: UUID(),
            promptID: "w13",
            startedAt: slots[0].record.startedAt,
            completedAt: completedAt,
            misses: 6,
            hintsUsed: 2,
            slotCount: 2,
            sessionID: session,
            promptRevision: String(repeating: "ab", count: 32),
            cue: WordPracticeState.cueProfile,
            slots: slots
        )
    }

    private func completedRun(canvasSize: CGSize, context: RunContext = RunContext()) throws -> PracticeRecord {
        let kanji = KanjiData(
            codePoint: "4e8c",
            element: nil,
            strokes: (1...2).map { KanjiStroke(strokeNumber: $0, pathData: "M10,10 L50,50", strokeType: nil) },
            components: []
        )
        let state = PracticeState(kanjiData: kanji, isRecall: true, context: context)
        let recorder = Recorder()
        state.onRunCompleted = { recorder.records.append($0) }
        state.noteCueShown()
        for index in 0..<state.totalStrokes {
            state.noteStrokeBegan(.finger)
            state.beginDrawing()
            state.beginValidation()
            state.processValidationResult(
                StrokeValidationResult(
                    score: 0.9,
                    accepted: true,
                    matchedStrokeIndex: index,
                    correctOrder: true,
                    frechetDistance: 0.1
                ),
                canvasSize: canvasSize
            )
            state.acknowledgeResult()
        }
        return try XCTUnwrap(recorder.records.first)
    }

    private func nilFields(of value: Any) -> [String] {
        Mirror(reflecting: value).children.compactMap { child in
            let mirror = Mirror(reflecting: child.value)
            guard mirror.displayStyle == .optional, mirror.children.isEmpty else {
                return nil
            }
            return child.label
        }
    }

    private func assertHasNoRicherFields(_ record: PracticeRecord, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(record.sessionID, file: file, line: line)
        XCTAssertNil(record.slot, file: file, line: line)
        XCTAssertNil(record.origin, file: file, line: line)
        XCTAssertNil(record.hint, file: file, line: line)
        XCTAssertNil(record.undos, file: file, line: line)
        XCTAssertNil(record.input, file: file, line: line)
        XCTAssertNil(record.canvasWidth, file: file, line: line)
        XCTAssertNil(record.canvasHeight, file: file, line: line)
        XCTAssertNil(record.idiom, file: file, line: line)
        XCTAssertNil(record.appVersion, file: file, line: line)
        XCTAssertNil(record.shownAt, file: file, line: line)
        XCTAssertNil(record.firstTouchAt, file: file, line: line)
        XCTAssertNil(record.interrupted, file: file, line: line)
        XCTAssertNil(record.configChanged, file: file, line: line)
        XCTAssertNil(record.strokes, file: file, line: line)
    }

    private func seconds(_ work: () -> Void) -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        work()
        return CFAbsoluteTimeGetCurrent() - start
    }

    func testMonthFileWrittenBeforeTheRicherFieldsStillLoads() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = """
        {"records":[\
        {"codePoint":"4e00","completedAt":"2026-10-09T01:00:00Z","exposed":false,\
        "id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","leniency":1,"misses":3,"mode":"study",\
        "revealed":false,"startedAt":"2026-10-09T00:59:00Z"},\
        {"codePoint":"4e8c","completedAt":"2026-10-12T03:00:00Z",\
        "evidence":{"disputed":1,"notEvaluated":0,"order":1,"position":0,"proportion":0,"shape":2},\
        "exposed":true,"gradingVersion":2,"id":"0F4D2C7B-8B53-4E0B-9C51-2B7D7C1E6A10",\
        "leniency":1.2649110640673518,"misses":3,"mode":"trace","revealed":false,\
        "startedAt":"2026-10-12T02:58:30Z","strictness":"normal"}\
        ],"version":1}
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("2026-10.json"))

        let store = PracticeHistoryStore(directory: directory, timeZone: utc)

        XCTAssertEqual(store.records.map(\.codePoint), ["4e00", "4e8c"])
        XCTAssertEqual(store.records.last?.evidence, MissEvidence(shape: 2, order: 1, disputed: 1))
        XCTAssertEqual(store.records.last?.strictness, "normal")
        for record in store.records {
            assertHasNoRicherFields(record)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["2026-10.json"])
    }

    func testWordsFileWrittenBeforeSlotsStillLoads() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = """
        {"records":[{"completedAt":"2026-10-15T08:00:00Z","hintsUsed":1,\
        "id":"5E0A3B1C-2D4F-4A6B-8C9D-0E1F2A3B4C5D","misses":2,"promptID":"w01",\
        "slotCount":2,"startedAt":"2026-10-15T07:59:00Z"}],"version":1}
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent(WordHistoryStore.fileName))

        let store = WordHistoryStore(directory: directory)

        let record = try XCTUnwrap(store.records.first)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(record.promptID, "w01")
        XCTAssertNil(record.sessionID)
        XCTAssertNil(record.promptRevision)
        XCTAssertNil(record.cue)
        XCTAssertNil(record.slots)
        XCTAssertEqual(record.effectiveMisses, 2)
        XCTAssertFalse(store.isBlocked)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [WordHistoryStore.fileName])
    }

    func testRecordWithEveryFieldRoundTrips() {
        let record = richRecord(completedAt: Date(timeIntervalSince1970: 1_791_000_000))
        XCTAssertEqual(nilFields(of: record), [])
        PracticeHistoryStore(directory: directory, timeZone: utc).add(record)

        XCTAssertEqual(PracticeHistoryStore(directory: directory, timeZone: utc).records, [record])
    }

    func testWordRecordWithEveryFieldRoundTrips() {
        let record = wordRecord(completedAt: Date(timeIntervalSince1970: 1_791_000_000))
        XCTAssertEqual(nilFields(of: record), [])
        WordHistoryStore(directory: directory).add(record)

        XCTAssertEqual(WordHistoryStore(directory: directory).records, [record])
    }

    func testCompletedRunFillsEveryField() throws {
        let record = try completedRun(
            canvasSize: CGSize(width: 361, height: 361),
            context: RunContext(sessionID: UUID(), origin: .randomSession, slot: 2)
        )

        XCTAssertEqual(nilFields(of: record), [])
        XCTAssertEqual(record.strokes?.count, 2)
    }

    func testZeroCountersAreLeftOutOfTheEncoding() throws {
        XCTAssertEqual(try encodedString(StrokeStat()), "{}")
        XCTAssertEqual(try encodedString(MissEvidence()), "{}")
        XCTAssertEqual(try encodedString(MissEvidence(boundary: 2)), #"{"boundary":2}"#)
        XCTAssertEqual(
            try encodedString(StrokeStat(attempts: 1, firstHint: "none", acceptedHint: "none")),
            #"{"acceptedHint":"none","attempts":1,"firstHint":"none"}"#
        )
        XCTAssertEqual(
            try encodedString(StrokeStat(attempts: 2, evidence: MissEvidence(order: 1), drawnInstead: [3], undone: 1)),
            #"{"attempts":2,"drawnInstead":[3],"evidence":{"order":1},"undone":1}"#
        )
    }

    func testMissingCountersDecodeAsZero() throws {
        let decoder = JSONDecoder()

        XCTAssertEqual(try decoder.decode(StrokeStat.self, from: Data("{}".utf8)), StrokeStat())
        XCTAssertEqual(try decoder.decode(MissEvidence.self, from: Data("{}".utf8)), MissEvidence())
        XCTAssertEqual(
            try decoder.decode(StrokeStat.self, from: Data(#"{"attempts":3,"evidence":{"shape":1}}"#.utf8)),
            StrokeStat(attempts: 3, evidence: MissEvidence(shape: 1))
        )
        XCTAssertEqual(
            try decoder.decode(MissEvidence.self, from: Data(#"{"order":2}"#.utf8)),
            MissEvidence(order: 2)
        )
    }

    func testUnusableCanvasSizeIsLeftOutAndTheRecordStillSaves() throws {
        let sizes = [
            CGSize(width: CGFloat.nan, height: 300),
            CGSize(width: 300, height: CGFloat.infinity),
            CGSize(width: -CGFloat.infinity, height: -CGFloat.infinity),
            CGSize(width: 0, height: 0),
            CGSize(width: -20, height: 300),
        ]
        let store = PracticeHistoryStore(directory: directory, timeZone: utc)

        for size in sizes {
            let record = try completedRun(canvasSize: size)
            XCTAssertNil(record.canvasWidth, "\(size)")
            XCTAssertNil(record.canvasHeight, "\(size)")
            XCTAssertEqual(record.configChanged, false, "\(size)")
            XCTAssertNoThrow(try storeEncoder().encode(record), "\(size)")
            store.add(record)
        }

        XCTAssertEqual(store.unsavedCount, 0)
        XCTAssertEqual(PracticeHistoryStore(directory: directory, timeZone: utc).records.count, sizes.count)
    }

    func testMeasureRecordSizeAndAYearOfHistory() throws {
        let encoder = storeEncoder()
        let sample = richRecord(completedAt: Date(timeIntervalSince1970: 1_750_000_000))
        let legacy = PracticeRecord(
            id: sample.id,
            codePoint: sample.codePoint,
            mode: sample.mode,
            revealed: sample.revealed,
            exposed: sample.exposed,
            misses: sample.misses,
            startedAt: sample.startedAt,
            completedAt: sample.completedAt,
            leniency: sample.leniency,
            strictness: sample.strictness,
            gradingVersion: sample.gradingVersion,
            evidence: sample.evidence
        )
        let recordBytes = try encoder.encode(sample).count
        let legacyBytes = try encoder.encode(legacy).count
        print("[measure] one 10-stroke PracticeRecord: \(recordBytes) bytes, \(legacyBytes) bytes without the new fields")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let perMonth = 1_500
        var practiceBytes = 0
        for month in 1...12 {
            let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: month, day: 1)))
            let records = (0..<perMonth).map { index in
                richRecord(completedAt: start.addingTimeInterval(Double(index) * 1_200))
            }
            let data = try encoder.encode(HistoryFile(version: PracticeHistoryStore.fileVersion, records: records))
            try data.write(to: directory.appendingPathComponent(String(format: "2025-%02d.json", month)))
            practiceBytes += data.count
        }

        var practiceStore: PracticeHistoryStore?
        let practiceLoad = seconds {
            practiceStore = PracticeHistoryStore(directory: directory, timeZone: utc)
        }
        let practice = try XCTUnwrap(practiceStore)
        XCTAssertEqual(practice.records.count, 12 * perMonth)
        let june = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 25)))
        let practiceAdd = seconds {
            practice.add(richRecord(completedAt: june))
        }
        XCTAssertEqual(practice.unsavedCount, 0)
        XCTAssertEqual(practice.records.count, 12 * perMonth + 1)
        print(
            "[measure] practice year: \(12 * perMonth) records in 12 month files, \(practiceBytes) bytes;"
                + " load \(String(format: "%.3f", practiceLoad)) s; one add \(String(format: "%.3f", practiceAdd)) s"
        )

        let wordDirectory = directory.appendingPathComponent("words", isDirectory: true)
        try FileManager.default.createDirectory(at: wordDirectory, withIntermediateDirectories: true)
        let yearStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let words = (0..<3_000).map { index in
            wordRecord(completedAt: yearStart.addingTimeInterval(Double(index) * 10_000))
        }
        let wordBytes = try encoder.encode(words[0]).count
        let wordData = try encoder.encode(HistoryFile(version: WordHistoryStore.fileVersion, records: words))
        try wordData.write(to: wordDirectory.appendingPathComponent(WordHistoryStore.fileName))

        var wordStore: WordHistoryStore?
        let wordLoad = seconds {
            wordStore = WordHistoryStore(directory: wordDirectory)
        }
        let wordHistory = try XCTUnwrap(wordStore)
        XCTAssertEqual(wordHistory.records.count, words.count)
        let wordAdd = seconds {
            wordHistory.add(wordRecord(completedAt: yearStart.addingTimeInterval(31_000_000)))
        }
        XCTAssertEqual(wordHistory.unsavedCount, 0)
        XCTAssertEqual(wordHistory.records.count, words.count + 1)
        print(
            "[measure] one 2-slot WordRecord: \(wordBytes) bytes; words year: \(words.count) records,"
                + " \(wordData.count) bytes; load \(String(format: "%.3f", wordLoad)) s;"
                + " one add \(String(format: "%.3f", wordAdd)) s"
        )

        XCTAssertLessThan(practiceLoad, 10)
        XCTAssertLessThan(practiceAdd, 5)
        XCTAssertLessThan(wordLoad, 10)
        XCTAssertLessThan(wordAdd, 10)
    }
}

@MainActor
private final class Recorder {
    var records: [PracticeRecord] = []
}
