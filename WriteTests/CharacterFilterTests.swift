import XCTest
@testable import Write

final class CharacterFilterTests: XCTestCase {
    private var store: KanjiDataStore!

    override func setUpWithError() throws {
        let stroke: [String: Any] = [
            "strokeNumber": 1, "pathData": "M10,10 L20,20", "strokeType": "㇐"
        ]
        let entries: [String: Any] = [
            "5c71": [
                "codePoint": "5c71", "element": "山", "strokes": [stroke],
                "components": [], "jlpt": 5, "grade": 1, "meanings": ["mountain"]
            ],
            "20b9f": [
                "codePoint": "20b9f", "element": "𠮟", "strokes": [stroke],
                "components": [], "grade": 8, "meanings": ["scold"]
            ],
            "51dc": [
                "codePoint": "51dc", "element": "凜", "strokes": [stroke],
                "components": [], "grade": 9, "meanings": ["cold"]
            ],
            "304b": [
                "codePoint": "304b", "element": "か", "strokes": [stroke],
                "components": [], "romaji": "ka"
            ],
            "30ab": [
                "codePoint": "30ab", "element": "カ", "strokes": [stroke],
                "components": [], "romaji": "ka"
            ]
        ]
        store = try KanjiDataStore(data: JSONSerialization.data(withJSONObject: entries))
    }

    func testWritingScripts() {
        XCTAssertEqual(WritingScript(codePoint: "5c71"), .kanji)
        XCTAssertEqual(WritingScript(codePoint: "304b"), .hiragana)
        XCTAssertEqual(WritingScript(codePoint: "30ab"), .katakana)
    }

    func testJLPTPickerFilters() {
        let kanji = store.lookup(codePoint: "5c71")!
        let hiragana = store.lookup(codePoint: "304b")!
        let katakana = store.lookup(codePoint: "30ab")!
        let order = CharacterFilter.pickerOrder(for: .jlpt)
        XCTAssertEqual(order.map(\.label),
                       ["All", "Hiragana", "Katakana", "N5", "N4", "N3", "N2", "N1"])
        XCTAssertEqual(order.map { $0.includes(kanji) },
                       [true, false, false, true, false, false, false, false])
        XCTAssertEqual(order.map { $0.includes(hiragana) },
                       [true, true, false, false, false, false, false, false])
        XCTAssertEqual(order.map { $0.includes(katakana) },
                       [true, false, true, false, false, false, false, false])
    }

    func testSchoolPickerFilters() {
        let order = CharacterFilter.pickerOrder(for: .school)
        XCTAssertEqual(order.map(\.label), [
            "All", "Hiragana", "Katakana",
            "Grade 1", "Grade 2", "Grade 3", "Grade 4", "Grade 5", "Grade 6", "Other Jōyō"
        ])
        let included = { (codePoint: String) in
            order.map { $0.includes(self.store.lookup(codePoint: codePoint)!) }
        }
        XCTAssertEqual(included("5c71"), [true, false, false, true, false, false, false, false, false, false])
        XCTAssertEqual(included("20b9f"), [true, false, false, false, false, false, false, false, false, true])
        XCTAssertEqual(included("51dc"), [true, false, false, false, false, false, false, false, false, false])
        XCTAssertEqual(included("304b"), [true, true, false, false, false, false, false, false, false, false])
    }

    func testFilterSchemes() {
        XCTAssertNil(CharacterFilter.all.scheme)
        XCTAssertNil(CharacterFilter.hiragana.scheme)
        XCTAssertEqual(CharacterFilter.jlpt(3).scheme, .jlpt)
        XCTAssertEqual(CharacterFilter.schoolGrade(2).scheme, .school)
        XCTAssertEqual(CharacterFilter.otherJoyo.scheme, .school)
    }

    func testRandomSchoolGrade() {
        XCTAssertEqual(store.randomCharacters(matching: .schoolGrade(1), count: 5).map(\.character), ["山"])
        XCTAssertEqual(store.randomCharacters(matching: .otherJoyo, count: 5).map(\.character), ["𠮟"])
    }

    func testCodePointsSortNumerically() {
        XCTAssertEqual(store.allCodePoints, ["304b", "30ab", "51dc", "5c71", "20b9f"])
    }

    func testRomajiSearchIsCaseInsensitive() {
        for query in ["ka", "KA"] {
            XCTAssertEqual(Set(store.search(query: query).map(\.codePoint)), ["304b", "30ab"])
        }
    }

    func testRandomHiragana() {
        XCTAssertEqual(store.randomCharacters(matching: .hiragana, count: 5).map(\.character), ["か"])
    }
}
