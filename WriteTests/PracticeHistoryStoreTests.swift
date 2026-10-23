import XCTest
@testable import Write

@MainActor
final class PracticeHistoryStoreTests: XCTestCase {
    private var directory: URL!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PracticeHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeRecord(completedAt: Date, codePoint: String = "4e00") -> PracticeRecord {
        PracticeRecord(
            id: UUID(),
            codePoint: codePoint,
            mode: PracticeRecord.recallMode,
            revealed: false,
            exposed: false,
            misses: 0,
            startedAt: completedAt.addingTimeInterval(-30),
            completedAt: completedAt,
            leniency: 1
        )
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }

    private func fileNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    func testRecordsSurviveReload() {
        let record = makeRecord(completedAt: date("2026-10-09T01:00:00Z"))
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        store.add(record)

        let reloaded = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        XCTAssertEqual(reloaded.records, [record])
    }

    func testRecordsArePartitionedByLocalCompletionMonth() throws {
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        store.add(makeRecord(completedAt: date("2026-09-30T14:30:00Z")))
        store.add(makeRecord(completedAt: date("2026-09-30T15:30:00Z")))

        XCTAssertEqual(try fileNames(), ["2026-09.json", "2026-10.json"])
    }

    func testDuplicateIdIsIgnored() {
        let record = makeRecord(completedAt: date("2026-10-09T01:00:00Z"))
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        store.add(record)
        store.add(record)

        XCTAssertEqual(store.records.count, 1)
    }

    func testFailedSaveIsRetainedAndRetriedWithSameId() throws {
        try FileManager.default.createDirectory(
            at: directory.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data().write(to: directory)
        let record = makeRecord(completedAt: date("2026-10-09T01:00:00Z"))
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        store.add(record)

        XCTAssertTrue(store.records.isEmpty)
        XCTAssertEqual(store.unsavedCount, 1)

        try FileManager.default.removeItem(at: directory)
        store.retryUnsaved()

        XCTAssertEqual(store.records.map(\.id), [record.id])
        XCTAssertEqual(store.unsavedCount, 0)
        XCTAssertEqual(PracticeHistoryStore(directory: directory, timeZone: tokyo).records.map(\.id), [record.id])
    }

    func testMonthIsBlockedWhenCorruptFileCannotBeMovedAside() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let corrupt = Data("not json".utf8)
        let monthURL = directory.appendingPathComponent("2026-10.json")
        try corrupt.write(to: monthURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)

        store.add(makeRecord(completedAt: date("2026-10-09T01:00:00Z")))
        store.add(makeRecord(completedAt: date("2026-11-02T01:00:00Z")))

        XCTAssertEqual(try Data(contentsOf: monthURL), corrupt)
        XCTAssertEqual(store.unsavedCount, 1)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertTrue(try fileNames().contains("2026-11.json"))
    }

    func testCorruptFileIsKeptAsideNotOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: directory.appendingPathComponent("2026-10.json"))

        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        XCTAssertTrue(store.records.isEmpty)
        store.add(makeRecord(completedAt: date("2026-10-09T01:00:00Z")))

        let names = try fileNames()
        XCTAssertTrue(names.contains("2026-10.json"))
        let aside = try XCTUnwrap(names.first { $0.hasPrefix("2026-10.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(aside)), corrupt)
    }

    func testGradingFieldsSurviveReload() {
        var record = makeRecord(completedAt: date("2026-10-09T01:00:00Z"))
        record.strictness = GradingStrictness.strict.rawValue
        record.gradingVersion = 2
        record.evidence = MissEvidence(shape: 1, position: 2, proportion: 1, order: 1, notEvaluated: 1, disputed: 1)
        PracticeHistoryStore(directory: directory, timeZone: tokyo).add(record)

        let reloaded = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        XCTAssertEqual(reloaded.records, [record])
    }

    func testFileWrittenBeforeGradingFieldsStillLoads() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = """
        {"records":[{"codePoint":"4e00","completedAt":"2026-10-09T01:00:00Z","exposed":false,\
        "id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","leniency":1,"misses":3,"mode":"study",\
        "revealed":false,"startedAt":"2026-10-09T00:59:00Z"}],"version":1}
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("2026-10.json"))

        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)

        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.misses, 3)
        XCTAssertNil(store.records.first?.evidence)
        XCTAssertNil(store.records.first?.strictness)
        XCTAssertEqual(try fileNames(), ["2026-10.json"])
    }

    private func monthCounts() throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for name in try fileNames() where name.hasSuffix(".json") {
            let data = try Data(contentsOf: directory.appendingPathComponent(name))
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            counts[name] = (object?["records"] as? [Any])?.count
        }
        return counts
    }

    func testMergeGroupsByLocalMonthAndKeepsRecordsSorted() throws {
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        let existing = makeRecord(completedAt: date("2026-10-09T01:00:00Z"))
        store.add(existing)
        let september = makeRecord(completedAt: date("2026-09-30T14:30:00Z"))
        let octoberEarly = makeRecord(completedAt: date("2026-09-30T15:30:00Z"))
        let octoberLate = makeRecord(completedAt: date("2026-10-20T01:00:00Z"))
        let november = makeRecord(completedAt: date("2026-11-02T01:00:00Z"))

        store.merge([november, octoberLate, september, octoberEarly])

        XCTAssertEqual(try monthCounts(), ["2026-09.json": 1, "2026-10.json": 3, "2026-11.json": 1])
        XCTAssertEqual(store.records.map(\.id), [september, octoberEarly, existing, octoberLate, november].map(\.id))
        let reloaded = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        XCTAssertEqual(reloaded.records.map(\.id), store.records.map(\.id))
    }

    func testMergeSkipsKnownAndRepeatedIds() throws {
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        let existing = makeRecord(completedAt: date("2026-10-09T01:00:00Z"))
        store.add(existing)
        let incoming = makeRecord(completedAt: date("2026-10-10T01:00:00Z"))

        store.merge([existing, incoming, incoming])

        XCTAssertEqual(store.records.map(\.id), [existing.id, incoming.id])
        XCTAssertEqual(try monthCounts(), ["2026-10.json": 2])
    }

    func testMergeOfNothingNewLeavesFilesAlone() throws {
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)

        store.merge([])

        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertTrue(store.records.isEmpty)
    }

    func testMergeIntoBlockedMonthKeepsRecordsUnsaved() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let corrupt = Data("not json".utf8)
        let monthURL = directory.appendingPathComponent("2026-10.json")
        try corrupt.write(to: monthURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        let store = PracticeHistoryStore(directory: directory, timeZone: tokyo)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        let blocked = makeRecord(completedAt: date("2026-10-09T01:00:00Z"))

        store.merge([blocked, makeRecord(completedAt: date("2026-11-02T01:00:00Z"))])
        store.merge([blocked])

        XCTAssertEqual(try Data(contentsOf: monthURL), corrupt)
        XCTAssertEqual(store.unsavedCount, 1)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertTrue(try fileNames().contains("2026-11.json"))
    }
}
