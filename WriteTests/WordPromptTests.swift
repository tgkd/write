import XCTest
@testable import Write

final class WordPromptTests: XCTestCase {

    private var prompts: [WordPrompt] = []
    private var kanjiStore: KanjiDataStore!

    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        let promptURL = try XCTUnwrap(
            Bundle.main.url(forResource: "word_prompts", withExtension: "json")
                ?? bundle.url(forResource: "word_prompts", withExtension: "json")
        )
        prompts = try WordPromptStore.decode(Data(contentsOf: promptURL))
        let kanjiURL = try XCTUnwrap(
            Bundle.main.url(forResource: "kanji_strokes", withExtension: "json")
                ?? bundle.url(forResource: "kanji_strokes", withExtension: "json")
        )
        kanjiStore = try KanjiDataStore(data: Data(contentsOf: kanjiURL))
    }

    private func containsKanji(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FFFF, 0x3005...0x3007:
                return true
            default:
                return false
            }
        }
    }

    func testBundledFileHasExactlyTwentyFourPrompts() {
        XCTAssertEqual(prompts.count, 24)
    }

    func testPromptIDsAreUnique() {
        XCTAssertEqual(Set(prompts.map(\.id)).count, prompts.count)
    }

    func testEveryKanjiSlotExistsWithGradeOneToThree() {
        for prompt in prompts {
            for segment in prompt.segments where segment.isKanji {
                let character = segment.kanjiCharacter
                XCTAssertNotNil(character, "\(prompt.id): slot must hold exactly one character")
                guard let character else {
                    continue
                }
                let kanji = kanjiStore.lookup(character: character)
                XCTAssertNotNil(kanji, "\(prompt.id): \(character) missing from kanji data")
                XCTAssertFalse(kanji?.strokes.isEmpty ?? true, "\(prompt.id): \(character) has no strokes")
                XCTAssertTrue((1...3).contains(kanji?.grade ?? 0), "\(prompt.id): \(character) is not grade 1-3")
            }
        }
    }

    func testSentenceTextAndReadingsContainNoKanji() {
        for prompt in prompts {
            XCTAssertFalse(containsKanji(prompt.before), prompt.id)
            XCTAssertFalse(containsKanji(prompt.after), prompt.id)
            XCTAssertFalse(containsKanji(prompt.reading), prompt.id)
            XCTAssertFalse(containsKanji(prompt.sentence), prompt.id)
            for segment in prompt.segments where !segment.isKanji {
                XCTAssertFalse(containsKanji(segment.text), prompt.id)
            }
        }
    }

    func testEveryPromptHasAKanjiSlotGlossAndNotes() {
        for prompt in prompts {
            XCTAssertFalse(prompt.kanjiSegmentIndices.isEmpty, prompt.id)
            XCTAssertFalse(prompt.gloss.trimmingCharacters(in: .whitespaces).isEmpty, prompt.id)
            XCTAssertFalse(prompt.notes.trimmingCharacters(in: .whitespaces).isEmpty, prompt.id)
            XCTAssertFalse(prompt.reading.isEmpty, prompt.id)
        }
    }

    func testKanaSegmentsAreTrailingOkuriganaOfTheReading() {
        for prompt in prompts {
            guard let lastKanji = prompt.kanjiSegmentIndices.last else {
                continue
            }
            let trailing = prompt.segments.suffix(from: lastKanji + 1)
            XCTAssertTrue(trailing.allSatisfy { !$0.isKanji }, prompt.id)
            XCTAssertEqual(
                prompt.segments.prefix(lastKanji + 1).filter { !$0.isKanji }.count, 0,
                "\(prompt.id): kana may only follow the last kanji"
            )
            let okurigana = trailing.map(\.text).joined()
            XCTAssertTrue(prompt.reading.hasSuffix(okurigana), prompt.id)
            XCTAssertGreaterThan(prompt.reading.count, okurigana.count, prompt.id)
        }
    }

    func testMixesSlotCountsAndOkurigana() {
        let slotCounts = Set(prompts.map(\.kanjiSegmentIndices.count))
        XCTAssertTrue(slotCounts.isSuperset(of: [1, 2, 3]))
        XCTAssertTrue(prompts.contains { $0.segments.contains { !$0.isKanji } })
    }

    func testSegmentsRoundTripThroughJSON() throws {
        let prompt = WordPrompt(
            id: "t1",
            before: "あの ",
            reading: "おおきい",
            after: " いぬ",
            gloss: "big",
            segments: [.kanji("大"), .kana("きい")],
            notes: "test"
        )
        let data = try JSONEncoder().encode(prompt)
        XCTAssertEqual(try JSONDecoder().decode(WordPrompt.self, from: data), prompt)
        XCTAssertEqual(prompt.answer, "大きい")
        XCTAssertEqual(prompt.slotID(segmentIndex: 0), "t1-0")
    }

    func testStoreResolvesRoutesInOrder() {
        let store = WordPromptStore(prompts: prompts)
        let ids = Array(prompts.prefix(3).map(\.id).reversed())
        XCTAssertEqual(store.prompts(for: WordSessionRoute(promptIDs: ids + ["missing"])).map(\.id), ids)
        XCTAssertEqual(Set(store.randomPromptIDs(count: 5)).count, 5)
    }
}
