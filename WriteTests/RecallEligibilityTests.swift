import XCTest
@testable import Write

final class RecallEligibilityTests: XCTestCase {

    private func kanji(
        _ codePoint: String,
        strokes: Int,
        on: [String]? = nil,
        kun: [String]? = nil,
        meanings: [String]? = nil,
        romaji: String? = nil
    ) -> KanjiData {
        let strokeList = (1...strokes).map { KanjiStroke(strokeNumber: $0, pathData: "M0,0 L1,1", strokeType: nil) }
        return KanjiData(
            codePoint: codePoint,
            element: nil,
            strokes: strokeList,
            components: [],
            onYomi: on,
            kunYomi: kun,
            meanings: meanings,
            romaji: romaji
        )
    }

    func testIdenticalCuesAreIneligible() {
        let a = kanji("51db", strokes: 15, on: ["リン"], meanings: ["cold"])
        let b = kanji("51dc", strokes: 15, on: ["リン"], meanings: ["cold"])
        let c = kanji("5c71", strokes: 3, on: ["サン"], meanings: ["mountain"])
        let eligibility = RecallEligibility(kanji: [a, b, c])

        XCTAssertFalse(eligibility.isEligible(a))
        XCTAssertFalse(eligibility.isEligible(b))
        XCTAssertTrue(eligibility.isEligible(c))
    }

    func testDifferentStrokeCountKeepsCuesDistinct() {
        let a = kanji("51db", strokes: 15, on: ["リン"], meanings: ["cold"])
        let b = kanji("51dc", strokes: 14, on: ["リン"], meanings: ["cold"])
        let eligibility = RecallEligibility(kanji: [a, b])

        XCTAssertTrue(eligibility.isEligible(a))
        XCTAssertTrue(eligibility.isEligible(b))
    }

    func testKanaWithSameRomajiInDifferentScriptsStayEligible() {
        let hiragana = kanji("3078", strokes: 1, romaji: "he")
        let katakana = kanji("30d8", strokes: 1, romaji: "he")
        let eligibility = RecallEligibility(kanji: [hiragana, katakana])

        XCTAssertTrue(eligibility.isEligible(hiragana))
        XCTAssertTrue(eligibility.isEligible(katakana))
    }

    func testCharacterWithoutCueIsIneligible() {
        let bare = kanji("4e00", strokes: 1)
        XCTAssertFalse(RecallEligibility(kanji: [bare]).isEligible(bare))
    }

    func testBundledVariantPairIsIneligible() {
        let store = KanjiDataStore()
        let rin = store.lookup(character: "凛")
        let mountain = store.lookup(character: "山")

        XCTAssertNotNil(rin)
        XCTAssertFalse(rin.map(store.recallEligibility.isEligible) ?? true)
        XCTAssertTrue(mountain.map(store.recallEligibility.isEligible) ?? false)
    }

    func testRecallQueueDropsIneligibleCharacters() throws {
        let store = KanjiDataStore()
        let rin = try XCTUnwrap(store.lookup(character: "凛"))
        let mountain = try XCTUnwrap(store.lookup(character: "山"))
        let codePoints = [rin.codePoint, mountain.codePoint]

        XCTAssertEqual(
            store.queue(for: SessionRoute(codePoints: codePoints, kind: .recall)).map(\.codePoint),
            [mountain.codePoint]
        )
        XCTAssertEqual(
            store.queue(for: SessionRoute(codePoints: codePoints, kind: .practice)).map(\.codePoint),
            codePoints
        )
    }

    func testEligibilityIsTheSameUnderEveryCueOrder() {
        struct ShownCue: Hashable {
            let script: WritingScript
            let lines: Set<RecallCue.Line>
            let strokeCount: Int
        }
        let store = KanjiDataStore()
        let all = store.allCodePoints.compactMap(store.lookup(codePoint:))
        let withCue = all.filter(RecallEligibility.hasCue)

        for order in RecallCueOrder.allCases {
            var groups: [ShownCue: [String]] = [:]
            for item in withCue {
                let shown = ShownCue(
                    script: item.script,
                    lines: Set(RecallCue(kanji: item, order: order).lines),
                    strokeCount: item.strokes.count
                )
                groups[shown, default: []].append(item.codePoint)
            }
            let ambiguous = Set(groups.values.filter { $0.count > 1 }.joined())
            XCTAssertEqual(ambiguous, store.recallEligibility.ambiguousCodePoints, "\(order)")
        }
    }

    func testRandomRecallCharactersAreEligible() {
        let store = KanjiDataStore()
        let picked = store.randomCharacters(matching: .all, count: 200, forRecall: true)

        XCTAssertEqual(picked.count, 200)
        XCTAssertTrue(picked.allSatisfy(store.recallEligibility.isEligible))
    }
}
