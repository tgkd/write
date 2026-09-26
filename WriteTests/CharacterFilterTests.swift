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
                "components": [], "jlpt": 5, "meanings": ["mountain"]
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

    func testEveryPickerFilter() {
        let kanji = store.lookup(codePoint: "5c71")!
        let hiragana = store.lookup(codePoint: "304b")!
        let katakana = store.lookup(codePoint: "30ab")!
        XCTAssertEqual(CharacterFilter.pickerOrder.map(\.label),
                       ["All", "Hiragana", "Katakana", "N5", "N4", "N3", "N2", "N1"])
        XCTAssertEqual(CharacterFilter.pickerOrder.map { $0.includes(kanji) },
                       [true, false, false, true, false, false, false, false])
        XCTAssertEqual(CharacterFilter.pickerOrder.map { $0.includes(hiragana) },
                       [true, true, false, false, false, false, false, false])
        XCTAssertEqual(CharacterFilter.pickerOrder.map { $0.includes(katakana) },
                       [true, false, true, false, false, false, false, false])
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
