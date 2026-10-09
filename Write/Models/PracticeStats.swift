import Foundation

struct PracticeStats: Equatable {
    struct DayActivity: Equatable {
        let day: Date
        let completions: Int
    }

    enum Reason: Equatable {
        case usedReveal
        case neededRetries(Int)
    }

    struct PracticeAgainItem: Equatable {
        let codePoint: String
        let reason: Reason
        let lastPracticed: Date
    }

    let practicedDays: Int
    let completedRuns: Int
    let distinctKanji: Int
    let recentDays: [DayActivity]
    let practiceAgain: [PracticeAgainItem]

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

        let hiddenStudyRuns = records.filter { $0.practiceMode == .study && !$0.exposed }
        let latestStudyRuns = Dictionary(grouping: hiddenStudyRuns, by: \.codePoint)
            .compactMapValues { runs in runs.max { $0.completedAt < $1.completedAt } }
        practiceAgain = latestStudyRuns.values
            .compactMap(Self.practiceAgainItem)
            .sorted { $0.lastPracticed > $1.lastPracticed }
    }

    private static func practiceAgainItem(for run: PracticeRecord) -> PracticeAgainItem? {
        let reason: Reason
        if run.revealed {
            reason = .usedReveal
        } else if run.misses > 0 {
            reason = .neededRetries(run.misses)
        } else {
            return nil
        }
        return PracticeAgainItem(codePoint: run.codePoint, reason: reason, lastPracticed: run.completedAt)
    }
}
