import XCTest
@testable import Write

@MainActor
final class WordHistoryStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WordHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeRecord(promptID: String = "w01", completedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> WordRecord {
        WordRecord(
            id: UUID(),
            promptID: promptID,
            startedAt: completedAt.addingTimeInterval(-40),
            completedAt: completedAt,
            misses: 2,
            hintsUsed: 1,
            slotCount: 2
        )
    }

    private var fileURL: URL {
        directory.appendingPathComponent(WordHistoryStore.fileName)
    }

    private func fileNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    func testRecordsSurviveReload() {
        let first = makeRecord(promptID: "w01")
        let second = makeRecord(promptID: "w13", completedAt: Date(timeIntervalSince1970: 1_800_000_100))
        let store = WordHistoryStore(directory: directory)
        store.add(first)
        store.add(second)

        XCTAssertEqual(store.records, [first, second])
        XCTAssertEqual(WordHistoryStore(directory: directory).records, [first, second])
    }

    func testRecordsLiveInOneFile() throws {
        let store = WordHistoryStore(directory: directory)
        store.add(makeRecord())
        store.add(makeRecord())

        XCTAssertEqual(try fileNames(), [WordHistoryStore.fileName])
    }

    func testDuplicateIdIsIgnored() {
        let record = makeRecord()
        let store = WordHistoryStore(directory: directory)
        store.add(record)
        store.add(record)

        XCTAssertEqual(store.records.count, 1)
    }

    func testFailedSaveIsRetainedAndRetried() throws {
        try FileManager.default.createDirectory(
            at: directory.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data().write(to: directory)
        let record = makeRecord()
        let store = WordHistoryStore(directory: directory)
        store.add(record)

        XCTAssertTrue(store.records.isEmpty)
        XCTAssertEqual(store.unsavedCount, 1)

        try FileManager.default.removeItem(at: directory)
        store.retryUnsaved()

        XCTAssertEqual(store.records.map(\.id), [record.id])
        XCTAssertEqual(store.unsavedCount, 0)
        XCTAssertEqual(WordHistoryStore(directory: directory).records.map(\.id), [record.id])
    }

    func testCorruptFileIsMovedAsideNotOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: fileURL)

        let store = WordHistoryStore(directory: directory)
        XCTAssertTrue(store.records.isEmpty)
        let record = makeRecord()
        store.add(record)

        let names = try fileNames()
        XCTAssertTrue(names.contains(WordHistoryStore.fileName))
        let aside = try XCTUnwrap(names.first { $0.hasPrefix("words.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(aside)), corrupt)
        XCTAssertEqual(WordHistoryStore(directory: directory).records.map(\.id), [record.id])
    }

    func testUnknownVersionIsMovedAside() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let future = Data(#"{"version":99,"records":[]}"#.utf8)
        try future.write(to: fileURL)

        _ = WordHistoryStore(directory: directory)

        let aside = try XCTUnwrap(try fileNames().first { $0.hasPrefix("words.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(aside)), future)
    }

    func testCorruptFileThatCannotBeMovedIsNeverWritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: fileURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        let store = WordHistoryStore(directory: directory)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)

        store.add(makeRecord())

        XCTAssertTrue(store.isBlocked)
        XCTAssertEqual(try Data(contentsOf: fileURL), corrupt)
        XCTAssertEqual(store.unsavedCount, 1)
        XCTAssertTrue(store.records.isEmpty)
    }
}
