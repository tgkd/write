import Combine
import Foundation

@MainActor
final class HistorySyncController: ObservableObject {
    nonisolated static let uiTestingArgument = "-uiTestingFreshHistory"

    @Published private(set) var status: HistorySyncStatus

    private let arguments: [String]
    private let stateURL: URL
    private let debounceInterval: TimeInterval
    private let makeCloud: () -> HistorySyncCloud
    private var engine: HistorySyncEngine?
    private weak var history: PracticeHistoryStore?
    private var observation: AnyCancellable?
    private var enabled = false
    private var rerunRequested = false
    private(set) var runningTask: Task<Void, Never>?

    nonisolated static var defaultStateURL: URL {
        PracticeHistoryStore.defaultDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("PracticeHistorySync.json")
    }

    convenience init() {
        self.init(
            arguments: ProcessInfo.processInfo.arguments,
            stateURL: Self.defaultStateURL,
            debounceInterval: 3,
            makeCloud: { CloudKitHistoryStore() }
        )
    }

    init(
        arguments: [String],
        stateURL: URL,
        debounceInterval: TimeInterval,
        makeCloud: @escaping () -> HistorySyncCloud
    ) {
        self.arguments = arguments
        self.stateURL = stateURL
        self.debounceInterval = debounceInterval
        self.makeCloud = makeCloud
        let saved = HistorySyncState.load(from: stateURL)
        status = saved.lastSyncedAt.map(HistorySyncStatus.synced) ?? .notSynced
    }

    nonisolated static func isSyncAllowed(enabled: Bool, arguments: [String]) -> Bool {
        enabled && !arguments.contains(uiTestingArgument)
    }

    func sceneBecameActive(history: PracticeHistoryStore, enabled: Bool) {
        self.enabled = enabled
        attach(history)
        requestSync()
    }

    func waitUntilIdle() async {
        while let task = runningTask {
            await task.value
        }
    }

    private var isAllowed: Bool {
        Self.isSyncAllowed(enabled: enabled, arguments: arguments)
    }

    private func attach(_ history: PracticeHistoryStore) {
        guard self.history !== history || observation == nil else {
            return
        }
        self.history = history
        observation = history.$records
            .dropFirst()
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.recordsChanged()
                }
            }
    }

    private func recordsChanged() {
        guard isAllowed, let engine, let history, engine.hasPendingUploads(in: history.records) else {
            return
        }
        requestSync()
    }

    private func requestSync() {
        guard isAllowed, let history else {
            return
        }
        guard runningTask == nil else {
            rerunRequested = true
            return
        }
        let engine = currentEngine()
        status = .syncing
        runningTask = Task { [weak self] in
            let outcome = await engine.sync(history: history)
            self?.finish(outcome, engine: engine)
        }
    }

    private func currentEngine() -> HistorySyncEngine {
        if let engine {
            return engine
        }
        let created = HistorySyncEngine(cloud: makeCloud(), stateURL: stateURL)
        engine = created
        return created
    }

    private func finish(_ outcome: HistorySyncEngine.Outcome, engine: HistorySyncEngine) {
        runningTask = nil
        switch outcome {
        case .synced(let date):
            status = .synced(date)
        case .accountUnavailable:
            status = .accountUnavailable
        case .deferred, .failed:
            status = engine.lastSyncedAt.map(HistorySyncStatus.synced) ?? .notSynced
        }
        if rerunRequested {
            rerunRequested = false
            requestSync()
        }
    }
}
