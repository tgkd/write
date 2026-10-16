import Foundation

@MainActor
final class WordHistoryStore: ObservableObject {
    private struct HistoryFile: Codable {
        let version: Int
        let records: [WordRecord]
    }

    static let fileVersion = 1
    static let fileName = "words.json"

    @Published private(set) var records: [WordRecord] = []
    @Published private(set) var unsavedCount: Int = 0
    @Published private(set) var isBlocked = false

    private let directory: URL
    private let fileManager = FileManager.default
    private var pending: [WordRecord] = [] {
        didSet {
            unsavedCount = pending.count
        }
    }

    nonisolated static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WordHistory", isDirectory: true)
    }

    init(directory: URL = WordHistoryStore.defaultDirectory) {
        self.directory = directory
        load()
    }

    private var fileURL: URL {
        directory.appendingPathComponent(Self.fileName)
    }

    func add(_ record: WordRecord) {
        let known = records.contains { $0.id == record.id } || pending.contains { $0.id == record.id }
        if !known {
            pending.append(record)
        }
        retryUnsaved()
    }

    func retryUnsaved() {
        guard !pending.isEmpty, !isBlocked else {
            return
        }
        let merged = records + pending
        do {
            try write(merged)
        } catch {
            return
        }
        records = merged
        pending = []
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            isBlocked = true
            return
        }
        if let file = decode(data), file.version == Self.fileVersion {
            records = file.records.sorted { $0.completedAt < $1.completedAt }
        } else if !moveAside() {
            isBlocked = true
        }
    }

    private func decode(_ data: Data) -> HistoryFile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HistoryFile.self, from: data)
    }

    private func write(_ records: [WordRecord]) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(HistoryFile(version: Self.fileVersion, records: records))
        try data.write(to: fileURL, options: .atomic)
    }

    private func moveAside() -> Bool {
        let target = directory.appendingPathComponent("words.corrupt-\(UUID().uuidString).json")
        do {
            try fileManager.moveItem(at: fileURL, to: target)
            return true
        } catch {
            return false
        }
    }
}
