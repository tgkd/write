import Foundation

struct HistorySyncState: Codable, Equatable {
    var uploadedIDs: Set<UUID> = []
    var changeToken: Data?
    var zoneReady = false
    var lastSyncedAt: Date?
    var notBefore: Date?

    static func load(from url: URL) -> HistorySyncState {
        guard let data = try? Data(contentsOf: url) else {
            return HistorySyncState()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(HistorySyncState.self, from: data)) ?? HistorySyncState()
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
