import XCTest
@testable import Write

final class DailyKanjiDataTests: XCTestCase {

    private var entries: [DailyKanji] = []
    private var store: KanjiDataStore!

    override func setUpWithError() throws {
        entries = DailyKanjiCatalog.load(from: Bundle(for: type(of: self)))
        guard let url = Bundle.main.url(forResource: "kanji_strokes", withExtension: "json")
                ?? Bundle(for: type(of: self)).url(forResource: "kanji_strokes", withExtension: "json") else {
            throw XCTSkip("kanji_strokes.json not found in app or test bundle")
        }
        let data = try Data(contentsOf: url)
        store = try KanjiDataStore(data: data)
    }

    func testCatalogHasEveryJLPTKanjiOnce() {
        XCTAssertEqual(entries.count, 2210)
        XCTAssertEqual(Set(entries.map(\.codePoint)).count, entries.count)
    }

    func testEntriesMatchTheStrokeData() throws {
        for entry in entries {
            let kanji = try XCTUnwrap(store.lookup(codePoint: entry.codePoint), entry.character)
            let meanings = kanji.meanings ?? []

            XCTAssertEqual(kanji.jlpt, entry.jlpt, entry.character)
            XCTAssertEqual(kanji.strokes.count, entry.strokeCount, entry.character)
            XCTAssertFalse(entry.meanings.isEmpty, entry.character)
            XCTAssertEqual(entry.meanings, Array(meanings.prefix(2)), entry.character)
            XCTAssertEqual(entry.onYomi, kanji.onYomi?.first, entry.character)
            XCTAssertEqual(entry.kunYomi, kanji.kunYomi?.first, entry.character)
        }
    }
}
