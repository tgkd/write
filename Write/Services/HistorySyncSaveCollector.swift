import Foundation

final class HistorySyncSaveCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var saved: Set<UUID> = []

    func markSaved(_ recordName: String) {
        guard let id = UUID(uuidString: recordName) else {
            return
        }
        lock.lock()
        saved.insert(id)
        lock.unlock()
    }

    var savedIDs: Set<UUID> {
        lock.lock()
        defer { lock.unlock() }
        return saved
    }
}
