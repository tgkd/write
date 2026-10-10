import XCTest
@testable import Write

@MainActor
final class SessionStateTests: XCTestCase {

    private func kanji(_ codePoint: String) -> KanjiData {
        KanjiData(
            codePoint: codePoint,
            element: nil,
            strokes: [KanjiStroke(strokeNumber: 1, pathData: "M0,0 L1,1", strokeType: nil)],
            components: []
        )
    }

    func testRepeatedResultForOneSlotReplacesIt() {
        let session = SessionState(kanjiQueue: [kanji("4e00"), kanji("4e8c")])
        session.recordResult(attemptCount: 2)
        session.recordResult(attemptCount: 0)

        XCTAssertEqual(session.results.count, 1)
        XCTAssertEqual(session.results.first?.attemptCount, 0)
    }

    func testSameCharacterInTwoSlotsKeepsBothResults() {
        let session = SessionState(kanjiQueue: [kanji("4e00"), kanji("4e00")])
        session.recordResult(attemptCount: 1)
        session.advance()
        session.recordResult(attemptCount: 3)

        XCTAssertEqual(session.results.map(\.slot), [0, 1])
        XCTAssertEqual(session.results.map(\.attemptCount), [1, 3])
    }

    func testSessionKeepsItsKind() {
        XCTAssertEqual(SessionState(kanjiQueue: [kanji("4e00")]).kind, .practice)
        XCTAssertEqual(SessionState(kanjiQueue: [kanji("4e00")], kind: .recall).kind, .recall)
    }

    func testResultKeepsHintUse() {
        let session = SessionState(kanjiQueue: [kanji("4e00")], kind: .recall)
        session.recordResult(attemptCount: 0, usedHint: true)

        XCTAssertEqual(session.results.first?.usedHint, true)
    }

    func testEmptyQueueIsAlreadyComplete() {
        XCTAssertTrue(SessionState(kanjiQueue: [], kind: .recall).isSessionComplete)
        XCTAssertFalse(SessionState(kanjiQueue: [kanji("4e00")]).isSessionComplete)
    }

    func testReviewRouteIsARecallOfTheFirstItems() {
        let day = Date(timeIntervalSince1970: 0)
        let items = ["4e00", "4e8c", "4e09"].map {
            PracticeStats.ReviewItem(codePoint: $0, reason: .usedHint, lastPracticed: day)
        }
        let route = SessionRoute.review(items, count: 2)

        XCTAssertEqual(route.codePoints, ["4e00", "4e8c"])
        XCTAssertEqual(route.kind, .recall)
    }
}
