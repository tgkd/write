import Foundation

struct ReviewPromptGate {
    struct Rules {
        var minDaysSinceFirstRun = 7
        var minRecentPracticeDays = 3
        var recentWindowDays = 30
        var minCompletedRuns = 20
        var cooldownDays = 120
    }

    static func isEligible(completedAt: [Date], lastAttemptAt: Date?, now: Date,
                           calendar: Calendar, rules: Rules = Rules()) -> Bool {
        guard let firstRun = completedAt.min(), completedAt.count >= rules.minCompletedRuns else {
            return false
        }
        if let lastAttemptAt, days(from: lastAttemptAt, to: now, calendar: calendar) < rules.cooldownDays {
            return false
        }
        guard days(from: firstRun, to: now, calendar: calendar) >= rules.minDaysSinceFirstRun else {
            return false
        }
        let recentWindow = 0..<rules.recentWindowDays
        let recentDays = Set(
            completedAt
                .filter { recentWindow.contains(days(from: $0, to: now, calendar: calendar)) }
                .map { calendar.startOfDay(for: $0) }
        )
        return recentDays.count >= rules.minRecentPracticeDays
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0
    }
}
