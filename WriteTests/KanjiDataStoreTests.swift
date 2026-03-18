import XCTest
@testable import Write

final class KanjiDataStoreTests: XCTestCase {

    private var store: KanjiDataStore!

    override func setUpWithError() throws {
        let testJSON = makeTestJSON()
        let data = try JSONSerialization.data(withJSONObject: testJSON)
        store = try KanjiDataStore(data: data)
    }

    // MARK: - Lookup tests

    func testLookupByCodePoint() {
        let result = store.lookup(codePoint: "4eee")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.codePoint, "4eee")
        XCTAssertEqual(result?.element, "仮")
    }

    func testLookupByCodePointCaseInsensitive() {
        let result = store.lookup(codePoint: "4EEE")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.codePoint, "4eee")
    }

    func testLookupByCharacter() {
        let result = store.lookup(character: "仮")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.codePoint, "4eee")
        XCTAssertEqual(result?.element, "仮")
    }

    func testLookupByCharacterMissing() {
        let result = store.lookup(character: "Z")
        XCTAssertNil(result)
    }

    func testLookupByCodePointMissing() {
        let result = store.lookup(codePoint: "ffff")
        XCTAssertNil(result)
    }

    // MARK: - Stroke data tests

    func testStrokeCount() {
        let kanji = store.lookup(codePoint: "4eee")
        XCTAssertEqual(kanji?.strokes.count, 6)
    }

    func testStrokeOrdering() {
        let kanji = store.lookup(codePoint: "4eee")!
        for (index, stroke) in kanji.strokes.enumerated() {
            XCTAssertEqual(stroke.strokeNumber, index + 1,
                "Stroke \(index) should have strokeNumber \(index + 1)")
        }
    }

    func testStrokePathDataNotEmpty() {
        let kanji = store.lookup(codePoint: "4eee")!
        for stroke in kanji.strokes {
            XCTAssertFalse(stroke.pathData.isEmpty,
                "Stroke \(stroke.strokeNumber) pathData should not be empty")
        }
    }

    func testStrokeTypes() {
        let kanji = store.lookup(codePoint: "4eee")!
        XCTAssertEqual(kanji.strokes[0].strokeType, "㇒")
        XCTAssertEqual(kanji.strokes[1].strokeType, "㇑")
        XCTAssertEqual(kanji.strokes[2].strokeType, "㇐")
    }

    // MARK: - Component tests

    func testComponents() {
        let kanji = store.lookup(codePoint: "4eee")!
        XCTAssertEqual(kanji.components.count, 2)
        XCTAssertEqual(kanji.components[0].element, "亻")
        XCTAssertEqual(kanji.components[0].position, "left")
        XCTAssertEqual(kanji.components[0].strokes.count, 2)
        XCTAssertEqual(kanji.components[1].element, "反")
        XCTAssertEqual(kanji.components[1].position, "right")
        XCTAssertEqual(kanji.components[1].strokes.count, 4)
    }

    // MARK: - Collection tests

    func testCount() {
        XCTAssertEqual(store.count, 2)
    }

    func testAllCodePoints() {
        let codePoints = store.allCodePoints
        XCTAssertEqual(codePoints.count, 2)
        XCTAssertTrue(codePoints.contains("4eee"))
        XCTAssertTrue(codePoints.contains("5c71"))
    }

    // MARK: - KanjiData character conversion

    func testCharacterConversion() {
        let kanji = store.lookup(codePoint: "4eee")!
        XCTAssertEqual(kanji.character, "仮")
    }

    func testCharacterConversionYama() {
        let kanji = store.lookup(codePoint: "5c71")!
        XCTAssertEqual(kanji.character, "山")
    }

    // MARK: - Simple kanji tests

    func testSimpleKanjiStrokeCount() {
        let yama = store.lookup(character: "山")
        XCTAssertNotNil(yama)
        XCTAssertEqual(yama?.strokes.count, 3)
    }

    func testSimpleKanjiNoComponents() {
        let yama = store.lookup(character: "山")!
        XCTAssertEqual(yama.components.count, 0)
    }

    // MARK: - Empty store

    func testEmptyStoreFromEmptyData() throws {
        let emptyData = "{}".data(using: .utf8)!
        let emptyStore = try KanjiDataStore(data: emptyData)
        XCTAssertEqual(emptyStore.count, 0)
        XCTAssertNil(emptyStore.lookup(codePoint: "4eee"))
    }

    // MARK: - Helpers

    private func makeTestJSON() -> [String: Any] {
        [
            "4eee": [
                "codePoint": "4eee",
                "element": "仮",
                "strokes": [
                    ["strokeNumber": 1, "pathData": "M32.01,17c0.22,1.93-0.31,3.72-1.02,5.37C26.5,32.93,20.8,42.85,10.5,55.7", "strokeType": "㇒"],
                    ["strokeNumber": 2, "pathData": "M25.48,37.5c0.57,0.57,1,1.69,1,3.24c0,11.3,0,33.32,0,46.02c0,3.05,0,5.56,0,7.25", "strokeType": "㇑"],
                    ["strokeNumber": 3, "pathData": "M47.34,22.01c1.27,0.33,3.61,0.53,4.86,0.33c11.42-1.84,23.3-4.59,32.75-5.84c2.08-0.27,3.38,0.16,4.44,0.32", "strokeType": "㇐"],
                    ["strokeNumber": 4, "pathData": "M52.65,23.81c1.14,1.14,1.49,2.48,1.42,4.7c-0.74,22.33-5.06,47.31-16.01,61.4", "strokeType": "㇒"],
                    ["strokeNumber": 5, "pathData": "M56.7,41.74c1.51,0.37,2.95,0.43,5.97-0.13", "strokeType": "㇇"],
                    ["strokeNumber": 6, "pathData": "M56.12,52.12c5.64,0.81,18.99,22.02,31.03,33.71", "strokeType": "㇏"]
                ],
                "components": [
                    [
                        "element": "亻",
                        "position": "left",
                        "strokes": [
                            ["strokeNumber": 1, "pathData": "M32.01,17c0.22,1.93", "strokeType": "㇒"],
                            ["strokeNumber": 2, "pathData": "M25.48,37.5c0.57,0.57", "strokeType": "㇑"]
                        ]
                    ],
                    [
                        "element": "反",
                        "position": "right",
                        "strokes": [
                            ["strokeNumber": 1, "pathData": "M47.34,22.01c1.27,0.33", "strokeType": "㇐"],
                            ["strokeNumber": 2, "pathData": "M52.65,23.81c1.14,1.14", "strokeType": "㇒"],
                            ["strokeNumber": 3, "pathData": "M56.7,41.74c1.51,0.37", "strokeType": "㇇"],
                            ["strokeNumber": 4, "pathData": "M56.12,52.12c5.64,0.81", "strokeType": "㇏"]
                        ]
                    ]
                ]
            ] as [String: Any],
            "5c71": [
                "codePoint": "5c71",
                "element": "山",
                "strokes": [
                    ["strokeNumber": 1, "pathData": "M50.25,14.48c0.5,1,0.75,2.25,0.75,3.48c0,18.97,0.05,56.28,0,65.53", "strokeType": "㇑"],
                    ["strokeNumber": 2, "pathData": "M21.5,48.12c0.25,0.87,0.5,2.01,0.5,2.98c0,7.46-0.03,22.79-0.03,32.03", "strokeType": "㇑"],
                    ["strokeNumber": 3, "pathData": "M14.5,83.25c2.36,0.5,5.32,0.39,7.68,0.15c16.8-1.72,35.87-3.15,56.31-3.15c3.3,0,4.55,0.35,5.72,0.57", "strokeType": "㇐"]
                ],
                "components": []
            ] as [String: Any]
        ]
    }
}
