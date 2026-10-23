import Foundation

protocol HistorySyncCloud: Sendable {
    func accountAvailable() async throws -> Bool
    func ensureZone() async throws
    func save(_ uploads: [HistorySyncUpload]) async throws -> Set<UUID>
    func fetchChanges(since token: Data?) async throws -> HistorySyncChanges
}
