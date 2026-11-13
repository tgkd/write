import XCTest
@testable import Write

final class ReviewPromptGateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private let now = ISO8601DateFormatter().date(from: "2026-10-09T03:00:00Z")!

    private func date(daysAgo: Int, minutes: Int = 0) -> Date {
        now.addingTimeInterval(Double(-daysAgo * 86_400 + minutes * 60))
    }

    private func runs(daysAgo: Int, count: Int) -> [Date] {
        (0..<count).map { date(daysAgo: daysAgo, minutes: -$0) }
    }

    private var eligibleHistory: [Date] {
        runs(daysAgo: 10, count: 10) + runs(daysAgo: 5, count: 5) + runs(daysAgo: 0, count: 5)
    }

    private func isEligible(_ completedAt: [Date], lastAttemptAt: Date? = nil) -> Bool {
        ReviewPromptGate.isEligible(
            completedAt: completedAt,
            lastAttemptAt: lastAttemptAt,
            now: now,
            calendar: calendar
        )
    }

    func testEligibleWhenAllRulesPass() {
        XCTAssertTrue(isEligible(eligibleHistory))
    }

    func testNoRecordsIsNotEligible() {
        XCTAssertFalse(isEligible([]))
    }

    func testManyRunsOnFirstDayAreNotEligible() {
        XCTAssertFalse(isEligible(runs(daysAgo: 0, count: 100)))
    }

    func testTooFewRunsAreNotEligible() {
        XCTAssertFalse(isEligible(Array(eligibleHistory.dropLast())))
    }

    func testFirstRunUnderSevenDaysAgoIsNotEligible() {
        let history = runs(daysAgo: 6, count: 10) + runs(daysAgo: 3, count: 5) + runs(daysAgo: 0, count: 5)
        XCTAssertFalse(isEligible(history))
    }

    func testOldPracticeDaysFallOutOfWindow() {
        let history = runs(daysAgo: 60, count: 10) + runs(daysAgo: 30, count: 5) + runs(daysAgo: 0, count: 5)
        XCTAssertFalse(isEligible(history))

        let withRecentDay = history + runs(daysAgo: 29, count: 1)
        XCTAssertFalse(isEligible(withRecentDay))

        let withTwoRecentDays = withRecentDay + runs(daysAgo: 2, count: 1)
        XCTAssertTrue(isEligible(withTwoRecentDays))
    }

    func testCooldownBlocks() {
        XCTAssertFalse(isEligible(eligibleHistory, lastAttemptAt: date(daysAgo: 0)))
        XCTAssertFalse(isEligible(eligibleHistory, lastAttemptAt: date(daysAgo: 119)))
    }

    func testCooldownEnds() {
        XCTAssertTrue(isEligible(eligibleHistory, lastAttemptAt: date(daysAgo: 120)))
    }

    @MainActor
    func testLastAttemptIsPersisted() {
        let suiteName = "ReviewPromptGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertNil(AppSettings(defaults: defaults).lastReviewAttemptAt)
        AppSettings(defaults: defaults).lastReviewAttemptAt = now
        XCTAssertEqual(AppSettings(defaults: defaults).lastReviewAttemptAt, now)
    }
}
