import Foundation

@MainActor
final class PracticeHistoryStore: ObservableObject {
    private struct MonthFile: Codable {
        let version: Int
        let records: [PracticeRecord]
    }

    static let fileVersion = 1

    @Published private(set) var records: [PracticeRecord] = []
    @Published private(set) var unsavedCount: Int = 0

    private let directory: URL
    private let calendar: Calendar
    private let fileManager = FileManager.default
    private var recordsByMonth: [String: [PracticeRecord]] = [:]
    private var blockedMonths: Set<String> = []
    private var pending: [PracticeRecord] = [] {
        didSet { unsavedCount = pending.count }
    }

    nonisolated static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PracticeHistory", isDirectory: true)
    }

    init(directory: URL = PracticeHistoryStore.defaultDirectory, timeZone: TimeZone = .current) {
        self.directory = directory
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        load()
    }

    func add(_ record: PracticeRecord) {
        let known = records.contains { $0.id == record.id } || pending.contains { $0.id == record.id }
        if !known {
            pending.append(record)
        }
        retryUnsaved()
    }

    func retryUnsaved() {
        pending = pending.filter { !persist($0) }
    }

    func monthKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private func persist(_ record: PracticeRecord) -> Bool {
        let key = monthKey(for: record.completedAt)
        guard !blockedMonths.contains(key) else { return false }
        let monthRecords = (recordsByMonth[key] ?? []) + [record]
        do {
            try write(monthRecords, toMonth: key)
        } catch {
            return false
        }
        recordsByMonth[key] = monthRecords
        records.append(record)
        return true
    }

    private func load() {
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names.sorted() where isMonthFileName(name) {
            let key = String(name.dropLast(".json".count))
            let url = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else {
                blockedMonths.insert(key)
                continue
            }
            if let file = decode(data), file.version == Self.fileVersion {
                recordsByMonth[key] = file.records
            } else if !moveAside(url, monthKey: key) {
                blockedMonths.insert(key)
            }
        }
        records = recordsByMonth.values.joined().sorted { $0.completedAt < $1.completedAt }
    }

    private func decode(_ data: Data) -> MonthFile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MonthFile.self, from: data)
    }

    private func write(_ records: [PracticeRecord], toMonth key: String) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(MonthFile(version: Self.fileVersion, records: records))
        try data.write(to: directory.appendingPathComponent("\(key).json"), options: .atomic)
    }

    private func moveAside(_ url: URL, monthKey key: String) -> Bool {
        let target = directory.appendingPathComponent("\(key).corrupt-\(UUID().uuidString).json")
        do {
            try fileManager.moveItem(at: url, to: target)
            return true
        } catch {
            return false
        }
    }

    private func isMonthFileName(_ name: String) -> Bool {
        name.range(of: #"^\d{4}-\d{2}\.json$"#, options: .regularExpression) != nil
    }
}
