import XCTest
@testable import Write

@MainActor
final class HistorySyncControllerTests: XCTestCase {
    private var directory: URL!
    private var cloud: FakeHistorySyncCloud!
    private var store: PracticeHistoryStore!
    private var cloudsCreated = 0

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistorySyncControllerTests-\(UUID().uuidString)", isDirectory: true)
        cloud = FakeHistorySyncCloud()
        cloudsCreated = 0
        store = PracticeHistoryStore(directory: directory.appendingPathComponent("History", isDirectory: true))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeController(arguments: [String] = []) -> HistorySyncController {
        HistorySyncController(
            arguments: arguments,
            stateURL: directory.appendingPathComponent("PracticeHistorySync.json"),
            debounceInterval: 0.05,
            makeCloud: { [unowned self] in
                cloudsCreated += 1
                return cloud
            }
        )
    }

    private func record() -> PracticeRecord {
        let completedAt = ISO8601DateFormatter().date(from: "2026-10-09T01:00:00Z")!
        return PracticeRecord(
            id: UUID(), codePoint: "4e00", mode: "trace", revealed: false, exposed: true, misses: 0,
            startedAt: completedAt, completedAt: completedAt, leniency: 1
        )
    }

    func testDisabledSettingNeverTouchesCloud() async {
        store.add(record())
        let controller = makeController()

        controller.sceneBecameActive(history: store, enabled: false)
        await controller.waitUntilIdle()

        XCTAssertEqual(cloudsCreated, 0)
        XCTAssertNil(controller.runningTask)
        XCTAssertEqual(controller.status, .notSynced)
    }

    func testUITestingArgumentTurnsSyncOff() async {
        XCTAssertFalse(HistorySyncController.isSyncAllowed(enabled: true, arguments: ["-uiTestingFreshHistory"]))
        XCTAssertTrue(HistorySyncController.isSyncAllowed(enabled: true, arguments: ["-practiceMode", "trace"]))
        let controller = makeController(arguments: ["Write", "-uiTestingFreshHistory"])

        controller.sceneBecameActive(history: store, enabled: true)
        await controller.waitUntilIdle()

        XCTAssertEqual(cloudsCreated, 0)
    }

    func testAccountUnavailableShowsStatusWithoutUploading() async {
        store.add(record())
        await cloud.setAvailable(false)
        let controller = makeController()

        controller.sceneBecameActive(history: store, enabled: true)
        await controller.waitUntilIdle()

        XCTAssertEqual(controller.status, .accountUnavailable)
        let calls = await cloud.callCount
        XCTAssertEqual(calls, 0)
    }

    func testSuccessfulSyncReportsDate() async {
        store.add(record())
        let controller = makeController()

        controller.sceneBecameActive(history: store, enabled: true)
        await controller.waitUntilIdle()

        guard case .synced = controller.status else {
            return XCTFail("expected synced, got \(controller.status)")
        }
        let saved = await cloud.savedIDs
        XCTAssertEqual(saved, store.records.map(\.id))
    }

    func testLocalRecordIsUploadedAfterDebounce() async throws {
        let controller = makeController()
        controller.sceneBecameActive(history: store, enabled: true)
        await controller.waitUntilIdle()

        let added = record()
        store.add(added)
        var saved: [UUID] = []
        for _ in 0..<100 where saved.isEmpty {
            try await Task.sleep(nanoseconds: 20_000_000)
            await controller.waitUntilIdle()
            saved = await cloud.savedIDs
        }

        XCTAssertEqual(saved, [added.id])
        XCTAssertEqual(cloudsCreated, 1)
    }
}
