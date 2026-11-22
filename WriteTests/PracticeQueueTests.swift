import XCTest
@testable import Write

final class PracticeQueueTests: XCTestCase {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }

    private let today = ISO8601DateFormatter().date(from: "2026-10-09T03:00:00Z")!

    private func record(
        _ codePoint: String,
        daysAgo: Int,
        mode: String = PracticeRecord.recallMode,
        revealed: Bool = false,
        exposed: Bool = false,
        misses: Int = 0
    ) -> PracticeRecord {
        let completedAt = today.addingTimeInterval(Double(-daysAgo * 86_400))
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
            evidence: nil
        )
    }

    private func newCodePoints(pool: [String], records: [PracticeRecord], count: Int, seed: UInt64 = 1) -> [String] {
        var generator = SeededGenerator(state: seed)
        return PracticeQueue.newCodePoints(pool: pool, records: records, count: count, using: &generator)
    }

    private func reviewCodePoints(pool: [String], records: [PracticeRecord], count: Int, seed: UInt64 = 1) -> [String] {
        var generator = SeededGenerator(state: seed)
        return PracticeQueue.reviewCodePoints(pool: pool, records: records, count: count, using: &generator)
    }

    private func route(focus: PracticeFocus, practicePool: [String], reviewPool: [String], records: [PracticeRecord]) -> SessionRoute {
        var generator = SeededGenerator(state: 1)
        return PracticeQueue.route(
            focus: focus,
            practicePool: practicePool,
            reviewPool: reviewPool,
            records: records,
            count: 10,
            using: &generator
        )
    }

    func testNewTakesOnlyUnpractisedWhenEnough() {
        let pool = ["a", "b", "c", "d", "e"]
        let records = [record("a", daysAgo: 1, mode: PracticeMode.trace.rawValue), record("b", daysAgo: 2)]
        for seed in UInt64(1)...20 {
            let result = newCodePoints(pool: pool, records: records, count: 3, seed: seed)
            XCTAssertEqual(result.count, 3)
            XCTAssertEqual(Set(result), ["c", "d", "e"])
        }
    }

    func testNewFillsWithPractisedAfterUnpractised() {
        let pool = ["a", "b", "c", "d"]
        let records = [record("a", daysAgo: 1), record("b", daysAgo: 2), record("c", daysAgo: 3, mode: PracticeMode.trace.rawValue)]
        for seed in UInt64(1)...20 {
            let result = newCodePoints(pool: pool, records: records, count: 3, seed: seed)
            XCTAssertEqual(result.count, 3)
            XCTAssertEqual(result.first, "d")
            XCTAssertEqual(Set(result).count, 3)
            XCTAssertTrue(Set(result.dropFirst()).isSubset(of: ["a", "b", "c"]))
        }
    }

    func testNewUsesWholePoolWithoutDuplicatesWhenCountIsLarge() {
        let pool = ["a", "b", "c"]
        let records = [record("a", daysAgo: 1), record("a", daysAgo: 2)]
        let result = newCodePoints(pool: pool, records: records, count: 10)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(Set(result.prefix(2)), ["b", "c"])
        XCTAssertEqual(result.last, "a")
    }

    func testNewIgnoresRecordsOutsidePool() {
        let pool = ["a", "b"]
        let records = [record("x", daysAgo: 1), record("a", daysAgo: 1)]
        let result = newCodePoints(pool: pool, records: records, count: 5)
        XCTAssertEqual(result, ["b", "a"])
    }

    func testNewIsDeterministicForSeed() {
        let pool = (0..<20).map { String(format: "%04x", 0x4e00 + $0) }
        XCTAssertEqual(newCodePoints(pool: pool, records: [], count: 5, seed: 7), newCodePoints(pool: pool, records: [], count: 5, seed: 7))
    }

    func testReviewOrdersMissedThenOldestThenUnpractised() {
        let pool = ["a", "b", "c", "d", "e", "f", "g"]
        let records = [
            record("a", daysAgo: 1, misses: 2),
            record("b", daysAgo: 3, revealed: true),
            record("c", daysAgo: 5),
            record("d", daysAgo: 9, mode: PracticeMode.trace.rawValue),
            record("d", daysAgo: 2, mode: PracticeMode.trace.rawValue),
            record("e", daysAgo: 7),
        ]
        for seed in UInt64(1)...20 {
            let result = reviewCodePoints(pool: pool, records: records, count: 7, seed: seed)
            XCTAssertEqual(Array(result.prefix(5)), ["a", "b", "e", "c", "d"])
            XCTAssertEqual(Set(result.suffix(2)), ["f", "g"])
        }
    }

    func testReviewMissedFollowsMissedCodePointsOrder() {
        let pool = ["a", "b", "c"]
        let records = [
            record("a", daysAgo: 4, misses: 1),
            record("b", daysAgo: 1, revealed: true),
            record("c", daysAgo: 2, misses: 3),
        ]
        let missed = PracticeQueue.missedCodePoints(pool: pool, records: records)
        XCTAssertEqual(missed, ["b", "c", "a"])
        XCTAssertEqual(reviewCodePoints(pool: pool, records: records, count: 3), missed)
    }

    func testReviewBreaksDateTieByCodePoint() {
        let pool = ["c", "a", "b"]
        let records = [record("c", daysAgo: 2), record("a", daysAgo: 2), record("b", daysAgo: 2)]
        XCTAssertEqual(reviewCodePoints(pool: pool, records: records, count: 3), ["a", "b", "c"])
    }

    func testReviewUsesLatestCompletionPerCodePoint() {
        let pool = ["a", "b"]
        let records = [record("a", daysAgo: 10), record("a", daysAgo: 1), record("b", daysAgo: 5)]
        XCTAssertEqual(reviewCodePoints(pool: pool, records: records, count: 2), ["b", "a"])
    }

    func testReviewStopsAtCount() {
        let pool = ["a", "b", "c", "d"]
        let records = [record("a", daysAgo: 1, misses: 1), record("b", daysAgo: 3), record("c", daysAgo: 2)]
        XCTAssertEqual(reviewCodePoints(pool: pool, records: records, count: 2), ["a", "b"])
    }

    func testReviewKeepsToPool() {
        let pool = ["b", "c"]
        let records = [record("a", daysAgo: 1, misses: 1), record("x", daysAgo: 4), record("b", daysAgo: 2)]
        let result = reviewCodePoints(pool: pool, records: records, count: 5)
        XCTAssertEqual(result, ["b", "c"])
    }

    func testNewKeepsToPool() {
        let pool = ["b", "c"]
        let records = [record("a", daysAgo: 1)]
        let result = newCodePoints(pool: pool, records: records, count: 5)
        XCTAssertEqual(Set(result), ["b", "c"])
        XCTAssertEqual(result.count, 2)
    }

    func testEmptyPoolOrNonPositiveCountGivesEmptyResult() {
        let records = [record("a", daysAgo: 1, misses: 1)]
        XCTAssertEqual(newCodePoints(pool: [], records: records, count: 5), [])
        XCTAssertEqual(reviewCodePoints(pool: [], records: records, count: 5), [])
        XCTAssertEqual(newCodePoints(pool: ["a", "b"], records: records, count: 0), [])
        XCTAssertEqual(reviewCodePoints(pool: ["a", "b"], records: records, count: 0), [])
        XCTAssertEqual(newCodePoints(pool: ["a", "b"], records: records, count: -1), [])
        XCTAssertEqual(reviewCodePoints(pool: ["a", "b"], records: records, count: -1), [])
    }

    func testRouteNewIsPracticeRandomSession() {
        let result = route(focus: .new, practicePool: ["a", "b"], reviewPool: ["a"], records: [record("a", daysAgo: 1, misses: 1)])
        XCTAssertEqual(result.kind, .practice)
        XCTAssertEqual(result.origin, .randomSession)
        XCTAssertEqual(result.codePoints, ["b", "a"])
    }

    func testRouteReviewWithMissedIsReviewSession() {
        let result = route(focus: .review, practicePool: ["a", "b", "c"], reviewPool: ["a", "b"], records: [record("b", daysAgo: 1, misses: 1)])
        XCTAssertEqual(result.kind, .recall)
        XCTAssertEqual(result.origin, .reviewSession)
        XCTAssertEqual(result.codePoints, ["b", "a"])
    }

    func testRouteReviewWithoutMissedIsRandomSession() {
        let result = route(focus: .review, practicePool: ["a", "b", "c"], reviewPool: ["a", "b"], records: [record("c", daysAgo: 1, misses: 1)])
        XCTAssertEqual(result.kind, .recall)
        XCTAssertEqual(result.origin, .randomSession)
        XCTAssertEqual(Set(result.codePoints), ["a", "b"])
    }
}
