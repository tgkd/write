import XCTest
@testable import Write

final class StudyEligibilityTests: XCTestCase {

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
        let eligibility = StudyEligibility(kanji: [a, b, c])

        XCTAssertFalse(eligibility.isEligible(a))
        XCTAssertFalse(eligibility.isEligible(b))
        XCTAssertTrue(eligibility.isEligible(c))
    }

    func testDifferentStrokeCountKeepsCuesDistinct() {
        let a = kanji("51db", strokes: 15, on: ["リン"], meanings: ["cold"])
        let b = kanji("51dc", strokes: 14, on: ["リン"], meanings: ["cold"])
        let eligibility = StudyEligibility(kanji: [a, b])

        XCTAssertTrue(eligibility.isEligible(a))
        XCTAssertTrue(eligibility.isEligible(b))
    }

    func testKanaWithSameRomajiInDifferentScriptsStayEligible() {
        let hiragana = kanji("3078", strokes: 1, romaji: "he")
        let katakana = kanji("30d8", strokes: 1, romaji: "he")
        let eligibility = StudyEligibility(kanji: [hiragana, katakana])

        XCTAssertTrue(eligibility.isEligible(hiragana))
        XCTAssertTrue(eligibility.isEligible(katakana))
    }

    func testCharacterWithoutCueIsIneligible() {
        let bare = kanji("4e00", strokes: 1)
        XCTAssertFalse(StudyEligibility(kanji: [bare]).isEligible(bare))
    }

    func testBundledVariantPairIsIneligible() {
        let store = KanjiDataStore()
        let rin = store.lookup(character: "凛")
        let mountain = store.lookup(character: "山")

        XCTAssertNotNil(rin)
        XCTAssertFalse(rin.map(store.studyEligibility.isEligible) ?? true)
        XCTAssertTrue(mountain.map(store.studyEligibility.isEligible) ?? false)
    }
}
