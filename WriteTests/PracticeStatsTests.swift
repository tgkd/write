import XCTest
@testable import Write

final class PracticeStatsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private let today = ISO8601DateFormatter().date(from: "2026-10-09T03:00:00Z")!

    private func record(
        _ codePoint: String,
        daysAgo: Int,
        mode: PracticeMode = .study,
        revealed: Bool = false,
        exposed: Bool = false,
        misses: Int = 0,
        minutes: Int = 0
    ) -> PracticeRecord {
        let completedAt = today.addingTimeInterval(Double(-daysAgo * 86_400 + minutes * 60))
        return PracticeRecord(
            id: UUID(),
            codePoint: codePoint,
            mode: mode.rawValue,
            revealed: revealed,
            exposed: exposed,
            misses: misses,
            startedAt: completedAt,
            completedAt: completedAt,
            leniency: 1
        )
    }

    func testCounts() {
        let stats = PracticeStats(
            records: [
                record("4e00", daysAgo: 0),
                record("4e00", daysAgo: 0, minutes: 5),
                record("4e8c", daysAgo: 2, mode: .trace),
            ],
            today: today,
            calendar: calendar,
            dayCount: 7
        )

        XCTAssertEqual(stats.practicedDays, 2)
        XCTAssertEqual(stats.completedRuns, 3)
        XCTAssertEqual(stats.distinctKanji, 2)
        XCTAssertEqual(stats.recentDays.map(\.completions), [0, 0, 0, 0, 1, 0, 2])
        XCTAssertEqual(stats.recentDays.last?.day, calendar.startOfDay(for: today))
    }

    func testPracticeAgainUsesLatestStudyRunPerCharacter() {
        let stats = PracticeStats(
            records: [
                record("4e00", daysAgo: 3, revealed: true),
                record("4e00", daysAgo: 1),
                record("4e8c", daysAgo: 2, misses: 2),
                record("4e09", daysAgo: 1, revealed: true),
                record("56db", daysAgo: 0, mode: .trace, misses: 5),
            ],
            today: today,
            calendar: calendar,
            dayCount: 7
        )

        XCTAssertEqual(stats.practiceAgain.map(\.codePoint), ["4e09", "4e8c"])
        XCTAssertEqual(stats.practiceAgain.map(\.reason), [.usedReveal, .neededRetries(2)])
    }

    func testExposedRunsNeitherNominateNorClear() {
        let stats = PracticeStats(
            records: [
                record("4e00", daysAgo: 2, misses: 3),
                record("4e00", daysAgo: 1, exposed: true),
                record("4e8c", daysAgo: 1, revealed: true, exposed: true),
            ],
            today: today,
            calendar: calendar,
            dayCount: 7
        )

        XCTAssertEqual(stats.practiceAgain.map(\.codePoint), ["4e00"])
        XCTAssertEqual(stats.practiceAgain.map(\.reason), [.neededRetries(3)])
        XCTAssertEqual(stats.completedRuns, 3)
    }

    func testEmptyHistory() {
        let stats = PracticeStats(records: [], today: today, calendar: calendar, dayCount: 35)

        XCTAssertEqual(stats.practicedDays, 0)
        XCTAssertEqual(stats.recentDays.count, 35)
        XCTAssertTrue(stats.practiceAgain.isEmpty)
    }
}
