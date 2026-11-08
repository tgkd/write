import XCTest
@testable import Write

final class PreprocessingTests: XCTestCase {

    private var store: KanjiDataStore!

    override func setUpWithError() throws {
        guard let url = Bundle.main.url(forResource: "kanji_strokes", withExtension: "json")
                ?? Bundle(for: type(of: self)).url(forResource: "kanji_strokes", withExtension: "json") else {
            throw XCTSkip("kanji_strokes.json not found in app or test bundle")
        }
        let data = try Data(contentsOf: url)
        store = try KanjiDataStore(data: data)
    }

    func testPreprocessedDataContainsKanji() {
        XCTAssertGreaterThan(store.count, 6000,
            "Should contain over 6000 CJK kanji from KanjiVG")
    }

    func testKanaCountsAndMetadata() {
        let characters = store.allCodePoints.compactMap { store.lookup(codePoint: $0) }
        let hiragana = characters.filter { $0.script == .hiragana }
        let katakana = characters.filter { $0.script == .katakana }
        XCTAssertEqual(hiragana.count, 104)
        XCTAssertEqual(katakana.count, 104)
        for kana in hiragana + katakana {
            XCTAssertFalse(kana.romaji?.isEmpty ?? true)
            XCTAssertNil(kana.jlpt)
        }
    }

    func testYoonInventoryAndGeometry() throws {
        let inventories = [("きぎしじちにひびぴみり", "ゃゅょ"), ("キギシジチニヒビピミリ", "ャュョ")]
        let prefixes = ["ky", "gy", "sh", "j", "ch", "ny", "hy", "by", "py", "my", "ry"]
        let smallStrokeCounts: [Character: Int] = ["ゃ": 3, "ゅ": 2, "ょ": 2, "ャ": 2, "ュ": 2, "ョ": 3]
        var expectedKeys: Set<String> = []
        for (bases, smalls) in inventories {
            for (base, prefix) in zip(bases, prefixes) {
                let big = try XCTUnwrap(store.lookup(character: base))
                for (small, vowel) in zip(smalls, "auo") {
                    let text = String(base) + String(small)
                    let key = text.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: "-")
                    expectedKeys.insert(key)
                    let item = try XCTUnwrap(store.lookup(codePoint: key), text)
                    XCTAssertEqual(item.text, text)
                    XCTAssertEqual(item.element, text)
                    XCTAssertEqual(item.romaji, prefix + String(vowel))
                    XCTAssertEqual(item.strokes.count, big.strokes.count + smallStrokeCounts[small]!)
                    XCTAssertEqual(item.strokes.map(\.strokeNumber), Array(1...item.strokes.count))
                    XCTAssertTrue(item.components.isEmpty)
                    for stroke in item.strokes {
                        let path = try StrokeRenderer.createPath(from: stroke.pathData)
                        let bounds = path.boundingBoxOfPath
                        XCTAssertFalse(path.isEmpty, key)
                        XCTAssertGreaterThanOrEqual(bounds.minX, 0, key)
                        XCTAssertGreaterThanOrEqual(bounds.minY, 0, key)
                        XCTAssertLessThanOrEqual(bounds.maxX, 109, key)
                        XCTAssertLessThanOrEqual(bounds.maxY, 109, key)
                    }
                }
            }
        }
        XCTAssertEqual(expectedKeys.count, 66)
        XCTAssertEqual(Set(store.allCodePoints.filter { $0.contains("-") }), expectedKeys)
        for small in "ゃゅょャュョ" {
            XCTAssertNil(store.lookup(character: small))
        }
    }

    func testKanaStrokesAndRomaji() {
        let a = store.lookup(codePoint: "3042")
        XCTAssertEqual(a?.strokes.count, 3)
        XCTAssertEqual(a?.romaji, "a")
        let katakanaA = store.lookup(codePoint: "30a2")
        XCTAssertEqual(katakanaA?.strokes.count, 2)
    }

    func testSchoolGradeCountsMatchCurriculum() {
        let grades = store.allCodePoints.compactMap { store.lookup(codePoint: $0)?.grade }
        let counts = Dictionary(grouping: grades, by: { $0 }).mapValues(\.count)
        XCTAssertEqual(counts[1], 80)
        XCTAssertEqual(counts[2], 160)
        XCTAssertEqual(counts[3], 200)
        XCTAssertEqual(counts[4], 202)
        XCTAssertEqual(counts[5], 193)
        XCTAssertEqual(counts[6], 191)
        XCTAssertEqual(counts[8], 1110)
    }

    func testGradedSupplementaryPlaneKanjiIsIncluded() {
        let shikaru = store.lookup(character: "𠮟")
        XCTAssertEqual(shikaru?.codePoint, "20b9f")
        XCTAssertEqual(shikaru?.grade, 8)
        XCTAssertEqual(shikaru?.strokes.count, 5)
        XCTAssertEqual(shikaru?.script, .kanji)
    }

    func testUngradedNonCoreCodePointsStayExcluded() {
        XCTAssertNil(store.lookup(codePoint: "2008a"))
        XCTAssertNil(store.lookup(codePoint: "f92e"))
        XCTAssertNil(store.lookup(codePoint: "ff01"))
    }

    func testKariHas6Strokes() {
        let kari = store.lookup(codePoint: "4eee")
        XCTAssertNotNil(kari, "仮 (U+4EEE) should exist in preprocessed data")
        XCTAssertEqual(kari?.strokes.count, 6, "仮 should have 6 strokes")
    }

    func testKariElement() {
        let kari = store.lookup(codePoint: "4eee")!
        XCTAssertEqual(kari.element, "仮")
    }

    func testKariStrokeOrderSequential() {
        let kari = store.lookup(codePoint: "4eee")!
        for (index, stroke) in kari.strokes.enumerated() {
            XCTAssertEqual(stroke.strokeNumber, index + 1)
        }
    }

    func testKariFirstStrokePathStartsWithMoveTo() {
        let kari = store.lookup(codePoint: "4eee")!
        let first = kari.strokes[0].pathData.first.map { String($0).uppercased() } ?? ""
        XCTAssertEqual(first, "M", "SVG path data should start with M or m (moveTo)")
    }

    func testKariComponents() {
        let kari = store.lookup(codePoint: "4eee")!
        XCTAssertEqual(kari.components.count, 2, "仮 should have 2 components (亻 + 反)")
        XCTAssertEqual(kari.components[0].element, "亻")
        XCTAssertEqual(kari.components[0].position, "left")
        XCTAssertEqual(kari.components[1].element, "反")
        XCTAssertEqual(kari.components[1].position, "right")
    }

    func testYamaHas3Strokes() {
        let yama = store.lookup(codePoint: "5c71")
        XCTAssertNotNil(yama, "山 (U+5C71) should exist")
        XCTAssertEqual(yama?.strokes.count, 3, "山 should have 3 strokes")
    }

    func testAllKanjiHaveAtLeastOneStroke() {
        for codePoint in store.allCodePoints {
            let kanji = store.lookup(codePoint: codePoint)
            XCTAssertNotNil(kanji)
            XCTAssertGreaterThan(kanji!.strokes.count, 0,
                "Kanji \(codePoint) should have at least 1 stroke")
        }
    }

    func testAllStrokesHaveValidPathData() {
        for codePoint in store.allCodePoints {
            let kanji = store.lookup(codePoint: codePoint)!
            for stroke in kanji.strokes {
                XCTAssertFalse(stroke.pathData.isEmpty,
                    "Kanji \(codePoint) stroke \(stroke.strokeNumber) should have path data")
                let first = stroke.pathData.first.map { String($0).uppercased() } ?? ""
                XCTAssertEqual(first, "M",
                    "Kanji \(codePoint) stroke \(stroke.strokeNumber) path should start with M or m (moveTo)")
            }
        }
    }

    func testStrokeNumbersAreSequential() {
        for codePoint in store.allCodePoints {
            let kanji = store.lookup(codePoint: codePoint)!
            for (index, stroke) in kanji.strokes.enumerated() {
                XCTAssertEqual(stroke.strokeNumber, index + 1,
                    "Kanji \(codePoint): stroke at index \(index) should have strokeNumber \(index + 1)")
            }
        }
    }
}
