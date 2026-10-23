import Foundation

struct PracticeStats: Equatable {
    struct DayActivity: Equatable {
        let day: Date
        let completions: Int
    }

    enum Reason: Equatable {
        case usedHint
        case neededRetries(Int)
    }

    struct ReviewItem: Equatable {
        let codePoint: String
        let reason: Reason
        let lastPracticed: Date
    }

    let practicedDays: Int
    let completedRuns: Int
    let distinctKanji: Int
    let recentDays: [DayActivity]
    let review: [ReviewItem]

    init(records: [PracticeRecord], today: Date, calendar: Calendar, dayCount: Int) {
        let countsByDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.completedAt) }
            .mapValues(\.count)
        practicedDays = countsByDay.count
        completedRuns = records.count
        distinctKanji = Set(records.map(\.codePoint)).count

        let lastDay = calendar.startOfDay(for: today)
        recentDays = (0..<dayCount).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: lastDay) else { return nil }
            return DayActivity(day: day, completions: countsByDay[day] ?? 0)
        }

        review = Self.reviewItems(from: records)
    }

    static func reviewItems(from records: [PracticeRecord]) -> [ReviewItem] {
        let hiddenRecallRuns = records.filter { $0.isRecall && !$0.exposed }
        let latestRecallRuns = Dictionary(grouping: hiddenRecallRuns, by: \.codePoint)
            .compactMapValues { runs in runs.max(by: Self.isEarlier) }
        return latestRecallRuns.values
            .compactMap(Self.reviewItem)
            .sorted { ($0.lastPracticed, $1.codePoint) > ($1.lastPracticed, $0.codePoint) }
    }

    static func isEarlier(_ lhs: PracticeRecord, _ rhs: PracticeRecord) -> Bool {
        (lhs.completedAt, lhs.id.uuidString) < (rhs.completedAt, rhs.id.uuidString)
    }

    static func effectiveMisses(of run: PracticeRecord) -> Int {
        max(0, run.misses - (run.evidence?.disputed ?? 0))
    }

    private static func reviewItem(for run: PracticeRecord) -> ReviewItem? {
        let reason: Reason
        let misses = effectiveMisses(of: run)
        if run.revealed {
            reason = .usedHint
        } else if misses > 0 {
            reason = .neededRetries(misses)
        } else {
            return nil
        }
        return ReviewItem(codePoint: run.codePoint, reason: reason, lastPracticed: run.completedAt)
    }
}
