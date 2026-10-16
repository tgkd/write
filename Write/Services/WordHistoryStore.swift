import Foundation

@MainActor
final class WordHistoryStore: ObservableObject {
    nonisolated static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WordHistory", isDirectory: true)
    }

    init(directory: URL = WordHistoryStore.defaultDirectory) {}
}
