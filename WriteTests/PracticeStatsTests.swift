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
        mode: String = PracticeRecord.recallMode,
        revealed: Bool = false,
        exposed: Bool = false,
        misses: Int = 0,
        minutes: Int = 0,
        evidence: MissEvidence? = nil
    ) -> PracticeRecord {
        let completedAt = today.addingTimeInterval(Double(-daysAgo * 86_400 + minutes * 60))
        return PracticeRecord(
            id: UUID(),
            codePoint: codePoint,
            mode: mode,
            revealed: revealed,
            exposed: exposed,
            misses: misses,
            startedAt: completedAt,
            completedAt: completedAt,
            leniency: 1,
            evidence: evidence
        )
    }

    func testCounts() {
        let stats = PracticeStats(
            records: [
                record("4e00", daysAgo: 0),
                record("4e00", daysAgo: 0, minutes: 5),
                record("4e8c", daysAgo: 2, mode: PracticeMode.trace.rawValue),
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

    func testReviewUsesLatestRecallRunPerCharacter() {
        let stats = PracticeStats(
            records: [
                record("4e00", daysAgo: 3, revealed: true),
                record("4e00", daysAgo: 1),
                record("4e8c", daysAgo: 2, misses: 2),
                record("4e09", daysAgo: 1, revealed: true),
                record("56db", daysAgo: 0, mode: PracticeMode.trace.rawValue, misses: 5),
            ],
            today: today,
            calendar: calendar,
            dayCount: 7
        )

        XCTAssertEqual(stats.review.map(\.codePoint), ["4e09", "4e8c"])
        XCTAssertEqual(stats.review.map(\.reason), [.usedHint, .neededRetries(2)])
        XCTAssertEqual(PracticeStats.reviewItems(from: []), [])
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

        XCTAssertEqual(stats.review.map(\.codePoint), ["4e00"])
        XCTAssertEqual(stats.review.map(\.reason), [.neededRetries(3)])
        XCTAssertEqual(stats.completedRuns, 3)
    }

    func testEmptyHistory() {
        let stats = PracticeStats(records: [], today: today, calendar: calendar, dayCount: 35)

        XCTAssertEqual(stats.practicedDays, 0)
        XCTAssertEqual(stats.recentDays.count, 35)
        XCTAssertTrue(stats.review.isEmpty)
    }

    func testRecallRunsKeepTheStoredStudyMode() {
        XCTAssertEqual(PracticeRecord.recallMode, "study")
        XCTAssertTrue(record("4e00", daysAgo: 0).isRecall)
        XCTAssertFalse(record("4e00", daysAgo: 0, mode: PracticeMode.copy.rawValue).isRecall)
    }

    func testDisputedMissesDoNotNominate() {
        let review = PracticeStats.reviewItems(from: [
            record("4e00", daysAgo: 1, misses: 1, evidence: MissEvidence(shape: 1, disputed: 1)),
            record("4e8c", daysAgo: 2, misses: 3, evidence: MissEvidence(shape: 3, disputed: 1)),
        ])

        XCTAssertEqual(review.map(\.codePoint), ["4e8c"])
        XCTAssertEqual(review.map(\.reason), [.neededRetries(2)])
    }

    func testDisputesNeverMakeMissesNegative() {
        let run = record("4e00", daysAgo: 1, misses: 1, evidence: MissEvidence(disputed: 3))

        XCTAssertEqual(PracticeStats.effectiveMisses(of: run), 0)
        XCTAssertTrue(PracticeStats.reviewItems(from: [run]).isEmpty)
    }

    func testPositionOnlyMissesStillNominate() {
        let review = PracticeStats.reviewItems(from: [
            record("4e00", daysAgo: 1, misses: 2, evidence: MissEvidence(position: 2)),
        ])

        XCTAssertEqual(review.map(\.reason), [.neededRetries(2)])
    }

    func testHintStillNominatesWhenMissesAreDisputed() {
        let review = PracticeStats.reviewItems(from: [
            record("4e00", daysAgo: 1, revealed: true, misses: 1, evidence: MissEvidence(shape: 1, disputed: 1)),
        ])

        XCTAssertEqual(review.map(\.reason), [.usedHint])
    }

    func testRecordsWithoutEvidenceKeepTheirMisses() {
        let review = PracticeStats.reviewItems(from: [
            record("4e00", daysAgo: 1, misses: 2),
        ])

        XCTAssertEqual(review.map(\.reason), [.neededRetries(2)])
    }

    func testOldRecordWithoutGradingFieldsDecodesAndNominates() throws {
        let json = """
        {
            "id": "7C9E6679-7425-40DE-944B-E07FC1F90AE7",
            "codePoint": "4e00",
            "mode": "study",
            "revealed": false,
            "exposed": false,
            "misses": 2,
            "startedAt": "2026-10-08T01:00:00Z",
            "completedAt": "2026-10-08T01:01:00Z",
            "leniency": 1.2649110640673518
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let old = try decoder.decode(PracticeRecord.self, from: Data(json.utf8))

        XCTAssertNil(old.strictness)
        XCTAssertNil(old.gradingVersion)
        XCTAssertNil(old.evidence)
        XCTAssertEqual(old.leniency, 1.2649110640673518)
        XCTAssertEqual(PracticeStats.reviewItems(from: [old]).map(\.reason), [.neededRetries(2)])
    }

    func testEvidenceMissingNewerCountsStillDecodes() throws {
        let decoded = try JSONDecoder().decode(MissEvidence.self, from: Data(#"{"shape": 2}"#.utf8))
        XCTAssertEqual(decoded, MissEvidence(shape: 2))
    }

    func testLatestRunTieIsBrokenByIdRegardlessOfOrder() {
        let completedAt = today
        let ids = [UUID(), UUID()].sorted { $0.uuidString < $1.uuidString }
        let hinted = PracticeRecord(
            id: ids[1], codePoint: "4e00", mode: PracticeRecord.recallMode, revealed: true, exposed: false,
            misses: 0, startedAt: completedAt, completedAt: completedAt, leniency: 1
        )
        let missed = PracticeRecord(
            id: ids[0], codePoint: "4e00", mode: PracticeRecord.recallMode, revealed: false, exposed: false,
            misses: 2, startedAt: completedAt, completedAt: completedAt, leniency: 1
        )

        let forward = PracticeStats.reviewItems(from: [hinted, missed])
        let backward = PracticeStats.reviewItems(from: [missed, hinted])

        XCTAssertEqual(forward.map(\.reason), [.usedHint])
        XCTAssertEqual(backward, forward)
    }

    func testReviewOrderTieIsBrokenByCodePoint() {
        let items = PracticeStats.reviewItems(from: [
            record("4e8c", daysAgo: 1, misses: 1),
            record("4e00", daysAgo: 1, misses: 1),
            record("4e09", daysAgo: 0, misses: 1)
        ])

        XCTAssertEqual(items.map(\.codePoint), ["4e09", "4e00", "4e8c"])
    }
}
