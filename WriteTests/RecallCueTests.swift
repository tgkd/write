import XCTest
@testable import Write

final class RecallCueTests: XCTestCase {

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

    private var eat: KanjiData {
        kanji(on: ["ショク", "ジキ"], kun: ["く.う", "た.べる"], meanings: ["eat", "food", "meal", "dine"])
    }

    func testMeaningsFirstLeadsWithMeanings() {
        let cue = RecallCue(kanji: eat, order: .meaningsFirst)

        XCTAssertEqual(cue.primary.map(\.kind), [.meanings])
        XCTAssertEqual(cue.primary.first?.text, "eat, food, meal")
        XCTAssertEqual(cue.secondary.map(\.kind), [.onYomi, .kunYomi])
        XCTAssertEqual(cue.secondary.map(\.text), ["ショク、 ジキ", "く.う、 た.べる"])
    }

    func testReadingsFirstLeadsWithReadings() {
        let cue = RecallCue(kanji: eat, order: .readingsFirst)

        XCTAssertEqual(cue.primary.map(\.kind), [.onYomi, .kunYomi])
        XCTAssertEqual(cue.secondary.map(\.kind), [.meanings])
    }

    func testMeaningsShownFollowEligibility() {
        let cue = RecallCue(kanji: eat, order: .meaningsFirst)
        let shown = cue.primary.first?.text.components(separatedBy: ", ")

        XCTAssertEqual(shown?.count, RecallEligibility.meaningsShown)
    }

    func testBothOrdersShowTheSameLines() {
        let samples = [
            eat,
            kanji(on: ["サン"]),
            kanji(meanings: ["mountain"]),
            kanji("3042", romaji: "a"),
            kanji(),
        ]
        for sample in samples {
            let meaningsFirst = RecallCue(kanji: sample, order: .meaningsFirst)
            let readingsFirst = RecallCue(kanji: sample, order: .readingsFirst)
            XCTAssertEqual(Set(meaningsFirst.lines), Set(readingsFirst.lines))
            XCTAssertEqual(meaningsFirst.lines.count, readingsFirst.lines.count)
        }
    }

    func testMissingGroupMovesTheOtherToPrimary() {
        let readingsOnly = kanji(on: ["サン"])
        let meaningsOnly = kanji(meanings: ["mountain"])

        XCTAssertEqual(RecallCue(kanji: readingsOnly, order: .meaningsFirst).primary.map(\.kind), [.onYomi])
        XCTAssertEqual(RecallCue(kanji: meaningsOnly, order: .readingsFirst).primary.map(\.kind), [.meanings])
        XCTAssertTrue(RecallCue(kanji: readingsOnly, order: .meaningsFirst).secondary.isEmpty)
    }

    func testKanaCueIsItsRomaji() {
        let cue = RecallCue(kanji: kanji("3042", romaji: "a"), order: .readingsFirst)

        XCTAssertEqual(cue.lines, [RecallCue.Line(kind: .romaji, text: "a")])
    }

    func testOrderRawValuesAreTheRecordedNames() {
        XCTAssertEqual(RecallCueOrder.meaningsFirst.rawValue, "meaningsFirst")
        XCTAssertEqual(RecallCueOrder.readingsFirst.rawValue, "readingsFirst")
    }
}
