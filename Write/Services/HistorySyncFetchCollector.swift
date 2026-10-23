import Foundation

final class HistorySyncFetchCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var payloads: [Data?] = []
    private var token: Data?
    private var failure: HistorySyncError?

    func append(_ payload: Data?) {
        lock.lock()
        payloads.append(payload)
        lock.unlock()
    }

    func setToken(_ token: Data?) {
        guard let token else {
            return
        }
        lock.lock()
        self.token = token
        lock.unlock()
    }

    func fail(_ error: HistorySyncError) {
        lock.lock()
        failure = error
        lock.unlock()
    }

    var error: HistorySyncError? {
        lock.lock()
        defer { lock.unlock() }
        return failure
    }

    var changes: HistorySyncChanges {
        lock.lock()
        defer { lock.unlock() }
        return HistorySyncChanges(payloads: payloads, token: token)
    }
}
