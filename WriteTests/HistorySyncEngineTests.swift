import XCTest
@testable import Write

actor FakeHistorySyncCloud: HistorySyncCloud {
    var available = true
    var zoneExists = false
    var ensureZoneCalls = 0
    var fetchTokens: [Data?] = []
    var savedBatches: [[UUID]] = []
    var expiredToken: Data?
    var nextSaveError: HistorySyncError?
    var batchLimit = Int.max
    private var log: [Data?] = []

    func setAvailable(_ value: Bool) {
        available = value
    }

    func setExpiredToken(_ token: Data?) {
        expiredToken = token
    }

    func setNextSaveError(_ error: HistorySyncError?) {
        nextSaveError = error
    }

    func setBatchLimit(_ limit: Int) {
        batchLimit = limit
    }

    func seed(_ payloads: [Data?]) {
        zoneExists = true
        log += payloads
    }

    func deleteZone() {
        zoneExists = false
        log = []
    }

    var savedIDs: [UUID] {
        savedBatches.flatMap { $0 }
    }

    var callCount: Int {
        ensureZoneCalls + fetchTokens.count + savedBatches.count
    }

    func accountAvailable() async throws -> Bool {
        available
    }

    func ensureZone() async throws {
        ensureZoneCalls += 1
        zoneExists = true
    }

    func save(_ uploads: [HistorySyncUpload]) async throws -> Set<UUID> {
        guard zoneExists else {
            throw HistorySyncError.zoneMissing
        }
        if let error = nextSaveError {
            nextSaveError = nil
            throw error
        }
        guard uploads.count <= batchLimit else {
            throw HistorySyncError.limitExceeded
        }
        savedBatches.append(uploads.map(\.id))
        log += uploads.map(\.payload)
        return Set(uploads.map(\.id))
    }

    func fetchChanges(since token: Data?) async throws -> HistorySyncChanges {
        fetchTokens.append(token)
        guard zoneExists else {
            throw HistorySyncError.zoneMissing
        }
        if let token, token == expiredToken {
            throw HistorySyncError.tokenExpired
        }
        let start = token.flatMap { Int(String(decoding: $0, as: UTF8.self)) } ?? 0
        return HistorySyncChanges(
            payloads: Array(log[min(start, log.count)...]),
            token: Data(String(log.count).utf8)
        )
    }
}

@MainActor
final class HistorySyncEngineTests: XCTestCase {
    private var directory: URL!
    private var stateURL: URL!
    private var cloud: FakeHistorySyncCloud!
    private var store: PracticeHistoryStore!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistorySyncEngineTests-\(UUID().uuidString)", isDirectory: true)
        stateURL = directory.appendingPathComponent("PracticeHistorySync.json")
        cloud = FakeHistorySyncCloud()
        store = PracticeHistoryStore(
            directory: directory.appendingPathComponent("History", isDirectory: true),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func record(_ time: String, codePoint: String = "4e00") -> PracticeRecord {
        let completedAt = ISO8601DateFormatter().date(from: time)!
        return PracticeRecord(
            id: UUID(),
            codePoint: codePoint,
            mode: PracticeRecord.recallMode,
            revealed: false,
            exposed: false,
            misses: 1,
            startedAt: completedAt.addingTimeInterval(-30),
            completedAt: completedAt,
            leniency: 1
        )
    }

    private func payload(_ record: PracticeRecord) throws -> Data {
        try PracticeHistoryStore.makeEncoder().encode(record)
    }

    private func makeEngine(now: @escaping () -> Date = Date.init) -> HistorySyncEngine {
        HistorySyncEngine(cloud: cloud, stateURL: stateURL, now: now)
    }

    func testUploadsOnlyRecordsNotYetUploaded() async {
        let first = record("2026-10-09T01:00:00Z")
        let second = record("2026-10-09T02:00:00Z")
        store.add(first)
        store.add(second)
        let engine = makeEngine()

        _ = await engine.sync(history: store)
        let third = record("2026-10-09T03:00:00Z")
        store.add(third)
        _ = await engine.sync(history: store)

        let batches = await cloud.savedBatches
        XCTAssertEqual(batches.map(Set.init), [[first.id, second.id], [third.id]])
    }

    func testUploadedSetSurvivesNewEngine() async {
        store.add(record("2026-10-09T01:00:00Z"))
        _ = await makeEngine().sync(history: store)

        _ = await makeEngine().sync(history: store)

        let batches = await cloud.savedBatches
        XCTAssertEqual(batches.count, 1)
    }

    func testUploadsInBatchesOfAtMost400() async {
        let base = ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z")!
        let records = (0..<401).map { offset in
            PracticeRecord(
                id: UUID(), codePoint: "4e00", mode: "trace", revealed: false, exposed: true, misses: 0,
                startedAt: base, completedAt: base.addingTimeInterval(Double(offset)), leniency: 1
            )
        }
        store.merge(records)

        _ = await makeEngine().sync(history: store)

        let sizes = await cloud.savedBatches.map(\.count)
        XCTAssertEqual(sizes, [400, 1])
    }

    func testLimitExceededSplitsBatch() async {
        store.merge((0..<5).map { record("2026-10-09T0\($0):00:00Z") })
        await cloud.setBatchLimit(2)

        let outcome = await makeEngine().sync(history: store)

        XCTAssertNotEqual(outcome, .failed)
        let saved = await cloud.savedIDs
        XCTAssertEqual(Set(saved), Set(store.records.map(\.id)))
    }

    func testDownloadedRecordsAreMergedAndNotReuploaded() async throws {
        let remote = record("2026-10-08T01:00:00Z", codePoint: "4e8c")
        await cloud.seed([try payload(remote)])
        let engine = makeEngine()

        _ = await engine.sync(history: store)
        XCTAssertEqual(store.records, [remote])
        XCTAssertFalse(engine.hasPendingUploads(in: store.records))

        _ = await engine.sync(history: store)
        _ = await makeEngine().sync(history: store)

        let saved = await cloud.savedIDs
        XCTAssertTrue(saved.isEmpty)
    }

    func testMergeSkipsDuplicatesAlreadyInStore() async throws {
        let local = record("2026-10-09T01:00:00Z")
        store.add(local)
        await cloud.seed([try payload(local)])

        _ = await makeEngine().sync(history: store)

        XCTAssertEqual(store.records.map(\.id), [local.id])
    }

    func testChangeTokenIsPersistedAndReused() async throws {
        await cloud.seed([try payload(record("2026-10-08T01:00:00Z"))])
        _ = await makeEngine().sync(history: store)

        let reloaded = HistorySyncState.load(from: stateURL)
        XCTAssertEqual(reloaded.changeToken, Data("1".utf8))

        _ = await makeEngine().sync(history: store)
        let tokens = await cloud.fetchTokens
        XCTAssertEqual(tokens, [nil, Data("1".utf8)])
    }

    func testExpiredTokenIsDroppedAndEverythingRefetched() async throws {
        let remote = record("2026-10-08T01:00:00Z")
        await cloud.seed([try payload(remote)])
        var state = HistorySyncState()
        state.changeToken = Data("1".utf8)
        state.zoneReady = true
        try state.save(to: stateURL)
        await cloud.setExpiredToken(Data("1".utf8))

        let outcome = await makeEngine().sync(history: store)

        guard case .synced = outcome else {
            return XCTFail("expected synced, got \(outcome)")
        }
        let tokens = await cloud.fetchTokens
        XCTAssertEqual(tokens, [Data("1".utf8), nil])
        XCTAssertEqual(store.records.map(\.id), [remote.id])
    }

    func testAccountUnavailableIsNoOp() async {
        store.add(record("2026-10-09T01:00:00Z"))
        await cloud.setAvailable(false)

        let outcome = await makeEngine().sync(history: store)

        XCTAssertEqual(outcome, .accountUnavailable)
        let calls = await cloud.callCount
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))
    }

    func testUndecodablePayloadsAreSkippedAndCounted() async throws {
        let good = record("2026-10-08T01:00:00Z")
        await cloud.seed([Data("not json".utf8), nil, try payload(good)])
        let engine = makeEngine()

        let outcome = await engine.sync(history: store)

        guard case .synced = outcome else {
            return XCTFail("expected synced, got \(outcome)")
        }
        XCTAssertEqual(engine.undecodableCount, 2)
        XCTAssertEqual(store.records.map(\.id), [good.id])
    }

    func testMissingZoneIsRecreatedAndHistoryReuploaded() async {
        let local = record("2026-10-09T01:00:00Z")
        store.add(local)
        let engine = makeEngine()
        _ = await engine.sync(history: store)
        await cloud.deleteZone()

        let outcome = await engine.sync(history: store)

        guard case .synced = outcome else {
            return XCTFail("expected synced, got \(outcome)")
        }
        let ensureCalls = await cloud.ensureZoneCalls
        let saved = await cloud.savedIDs
        XCTAssertEqual(ensureCalls, 2)
        XCTAssertEqual(saved, [local.id, local.id])
    }

    func testRetryAfterDefersUntilDeadline() async {
        store.add(record("2026-10-09T01:00:00Z"))
        await cloud.setNextSaveError(.retryAfter(60))
        let start = Date()
        var clock = start
        let engine = makeEngine { clock }

        let first = await engine.sync(history: store)
        clock = start.addingTimeInterval(10)
        let second = await engine.sync(history: store)
        clock = start.addingTimeInterval(61)
        let third = await engine.sync(history: store)

        XCTAssertEqual(first, .failed)
        XCTAssertEqual(second, .deferred)
        XCTAssertEqual(third, .synced(clock))
        let saved = await cloud.savedIDs
        XCTAssertEqual(saved, store.records.map(\.id))
    }

    func testTransientFailureRetriesAtNextTrigger() async {
        store.add(record("2026-10-09T01:00:00Z"))
        await cloud.setNextSaveError(.transient)
        let engine = makeEngine()

        let first = await engine.sync(history: store)
        let second = await engine.sync(history: store)

        XCTAssertEqual(first, .failed)
        guard case .synced = second else {
            return XCTFail("expected synced, got \(second)")
        }
        let saved = await cloud.savedIDs
        XCTAssertEqual(saved, store.records.map(\.id))
    }
}
