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
}
