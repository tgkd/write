import Foundation

@MainActor
final class HistorySyncEngine {
    enum Outcome: Equatable {
        case synced(Date)
        case accountUnavailable
        case deferred
        case failed
    }

    static let batchSize = 400

    private let cloud: HistorySyncCloud
    private let stateURL: URL
    private let now: () -> Date
    private(set) var state: HistorySyncState
    private(set) var undecodableCount = 0

    init(cloud: HistorySyncCloud, stateURL: URL, now: @escaping () -> Date = Date.init) {
        self.cloud = cloud
        self.stateURL = stateURL
        self.now = now
        state = HistorySyncState.load(from: stateURL)
    }

    var lastSyncedAt: Date? {
        state.lastSyncedAt
    }

    func hasPendingUploads(in records: [PracticeRecord]) -> Bool {
        records.contains { !state.uploadedIDs.contains($0.id) }
    }

    func sync(history: PracticeHistoryStore) async -> Outcome {
        if let notBefore = state.notBefore, now() < notBefore {
            return .deferred
        }
        do {
            guard try await cloud.accountAvailable() else {
                return .accountUnavailable
            }
            do {
                try await pass(history: history)
            } catch HistorySyncError.zoneMissing {
                resetForMissingZone()
                try await pass(history: history)
            }
            let finished = now()
            state.notBefore = nil
            state.lastSyncedAt = finished
            persist()
            return .synced(finished)
        } catch HistorySyncError.accountUnavailable {
            return .accountUnavailable
        } catch HistorySyncError.retryAfter(let seconds) {
            state.notBefore = now().addingTimeInterval(seconds)
            persist()
            return .failed
        } catch {
            return .failed
        }
    }

    private func pass(history: PracticeHistoryStore) async throws {
        if !state.zoneReady {
            try await cloud.ensureZone()
            state.zoneReady = true
            persist()
        }
        try await upload(history.records)
        try await download(into: history)
    }

    private func resetForMissingZone() {
        state.zoneReady = false
        state.changeToken = nil
        state.uploadedIDs = []
        persist()
    }

    private func upload(_ records: [PracticeRecord]) async throws {
        let pending = records.filter { !state.uploadedIDs.contains($0.id) }
        guard !pending.isEmpty else {
            return
        }
        let uploads = await Self.encode(pending)
        var start = 0
        while start < uploads.count {
            let end = min(start + Self.batchSize, uploads.count)
            try await save(uploads[start..<end])
            start = end
        }
    }

    private func save(_ batch: ArraySlice<HistorySyncUpload>) async throws {
        do {
            let saved = try await cloud.save(Array(batch))
            state.uploadedIDs.formUnion(saved)
            persist()
        } catch HistorySyncError.limitExceeded where batch.count > 1 {
            let middle = batch.startIndex + batch.count / 2
            try await save(batch[batch.startIndex..<middle])
            try await save(batch[middle..<batch.endIndex])
        }
    }

    private func download(into history: PracticeHistoryStore) async throws {
        let changes: HistorySyncChanges
        do {
            changes = try await cloud.fetchChanges(since: state.changeToken)
        } catch HistorySyncError.tokenExpired {
            state.changeToken = nil
            persist()
            changes = try await cloud.fetchChanges(since: nil)
        }
        let (records, failures) = await Self.decode(changes.payloads)
        undecodableCount = failures
        state.uploadedIDs.formUnion(records.map(\.id))
        state.changeToken = changes.token
        persist()
        history.merge(records)
    }

    private func persist() {
        try? state.save(to: stateURL)
    }

    private nonisolated static func encode(_ records: [PracticeRecord]) async -> [HistorySyncUpload] {
        let encoder = PracticeHistoryStore.makeEncoder()
        return records.compactMap { record in
            guard let payload = try? encoder.encode(record) else {
                return nil
            }
            return HistorySyncUpload(id: record.id, payload: payload, completedAt: record.completedAt)
        }
    }

    private nonisolated static func decode(_ payloads: [Data?]) async -> ([PracticeRecord], Int) {
        let decoder = PracticeHistoryStore.makeDecoder()
        var records: [PracticeRecord] = []
        var failures = 0
        for payload in payloads {
            if let payload, let record = try? decoder.decode(PracticeRecord.self, from: payload) {
                records.append(record)
            } else {
                failures += 1
            }
        }
        return (records, failures)
    }
}
