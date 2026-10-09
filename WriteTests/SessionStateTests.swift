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

    func testSessionStartsInRequestedMode() {
        XCTAssertEqual(SessionState(kanjiQueue: [kanji("4e00")], mode: .study).mode, .study)
    }
}
