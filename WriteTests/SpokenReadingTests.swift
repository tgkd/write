import XCTest
@testable import Write

final class SpokenReadingTests: XCTestCase {

    private func kanji(
        _ codePoint: String = "98df",
        on: [String]? = nil,
        kun: [String]? = nil,
        meanings: [String]? = nil,
        romaji: String? = nil
    ) -> KanjiData {
        KanjiData(
            codePoint: codePoint,
            element: nil,
            strokes: [KanjiStroke(strokeNumber: 1, pathData: "M0,0 L1,1", strokeType: nil)],
            components: [],
            onYomi: on,
            kunYomi: kun,
            meanings: meanings,
            romaji: romaji
        )
    }

    func testOkuriganaMarkerIsRemoved() {
        XCTAssertEqual(SpokenReading.clean("た.べる"), "たべる")
    }

    func testAffixDashesAreDropped() {
        XCTAssertEqual(SpokenReading.clean("-び"), "び")
        XCTAssertEqual(SpokenReading.clean("あ.げる-"), "あげる")
        XCTAssertEqual(SpokenReading.clean("-ジ-"), "ジ")
    }

    func testParenthesisedTextIsDropped() {
        XCTAssertEqual(SpokenReading.clean("(お)さ.める"), "さめる")
        XCTAssertEqual(SpokenReading.clean("はし（ら）"), "はし")
    }

    func testKatakanaOnReadingIsKept() {
        XCTAssertEqual(SpokenReading.clean("ショク"), "ショク")
    }

    func testReadingsFollowTheDisplayedOrderWithAtMostTwoOfEach() {
        let eat = kanji(on: ["ショク", "ジキ", "シ"], kun: ["く.う", "く.らう", "た.べる"])
        XCTAssertEqual(SpokenReading.text(for: eat), "ショク、ジキ、くう、くらう")
    }

    func testDuplicatesAfterCleaningAreSpokenOnce() {
        let up = kanji(on: ["ジョウ"], kun: ["うえ", "-うえ", "うわ-"])
        XCTAssertEqual(SpokenReading.text(for: up), "ジョウ、うえ、うわ")
    }

    func testReadingsThatCleanToNothingAreSkipped() {
        let odd = kanji(on: ["(ア)"], kun: ["-", "み"])
        XCTAssertEqual(SpokenReading.text(for: odd), "み")
    }

    func testKanjiWithoutReadingsHasNothingToSpeak() {
        XCTAssertNil(SpokenReading.text(for: kanji(meanings: ["eat"])))
    }

    func testKanaSpeaksTheKanaItself() {
        XCTAssertEqual(SpokenReading.text(for: kanji("3042", romaji: "a")), "あ")
        XCTAssertEqual(SpokenReading.text(for: kanji("30ab", romaji: "ka")), "カ")
    }

    func testNoBundledReadingKeepsDictionaryNotation() {
        let store = KanjiDataStore()
        let notation = CharacterSet(charactersIn: ".-()（）")
        for kanji in store.allCodePoints.compactMap(store.lookup(codePoint:)) {
            guard let text = SpokenReading.text(for: kanji) else {
                continue
            }
            XCTAssertNil(text.rangeOfCharacter(from: notation), "\(kanji.character): \(text)")
        }
    }
}
