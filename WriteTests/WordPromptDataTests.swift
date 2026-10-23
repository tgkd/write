import XCTest
@testable import Write

final class WordPromptDataTests: XCTestCase {

    private static let legacyRevisions: [String: String] = [
        "w01": "9074f44ae7383a0bf583da78ed22c42e089c3413df556b234ee26d9a5d49da4a",
        "w02": "b2569885c740c81a1fda1d248ac6f6beec796fa032832c1669e4a247635adf40",
        "w03": "1e9f6c8f54974eff3ba15c93196080f0cf62f3cf19faadf44caa6ec67e5b963a",
        "w04": "a57e137addf100791de6d31537bb29928316ef4ce7e13a243ec5b2d4da3a3f45",
        "w05": "cf021975bc492df1a253894a31ea073f5db7a97592df5540b529b9e08284bb9a",
        "w06": "e11e75a15dd537304f18a349762caabbf962bc1409b65ba9edf5f262cec9056e",
        "w07": "d4fc1690d464cbdb8812598afba595b62b98088d5638d9dec528ca89b374452a",
        "w08": "52f9a1105a354d2b778c5e5ecfa5b855aa01d0faa37dabbd2c5a005c5bd28ed3",
        "w09": "bb17cb08e0f17a8439c062fbd14cdc50a4c6b18858529580f18c0bdbfcda6838",
        "w10": "ce067d6481b1d329d4df69bbca38209f9fd08ee0e7ef535984800eb7130e5199",
        "w11": "8164ad93ff2f0eec18d00ab7c2271d0a86fe2b2a08937c191d4b8053b2205fbc",
        "w12": "0ca92d938e0aeed173a74363c1726e657d823d74073b24fd1da6f1ba9618ca99",
        "w13": "ac9c28ffd90db6760d84057f30e74b2cbf94ffa3e594e78c77cc3bf789a2a149",
        "w14": "92e4a7c8c757287a95b5b5336427692f9914ad0dde2a36f214ac506a1e6666a5",
        "w15": "66a888c566a4d44a4076da7866889c2c8df5f0cf0bbde1c5929ad590d58a4a39",
        "w16": "6ca14e0f5fbd71621cfbd5006841f9759ecaad2504acfdab94c33e267d70394b",
        "w17": "b190657ffef95d6d3cbb8b759e19cba8fea64abee7cbb0a380149f8872d7e90b",
        "w18": "61b04daa423b7ebd8848419120db36e547c04c2f3178111a41ce8e2343b5bf0c",
        "w19": "dcd5759c2784590622320c8f1c8f3a4a31c3ae85075f21b484a7383555d8eee3",
        "w20": "b95285a08f982b2b7c41e7bb910fdb91e7cc4b2431d41db42a62c4871f48a8bd",
        "w21": "b7cda747e808d205d09b291ff0ce1877bd0817ba60cbfdeb69a69ad37125f5b3",
        "w22": "50bbcbf0cd1a3fed3a2eebdc73e8d30fbef71f3c9244232b0992c87ee5d5f74f",
        "w23": "ddde0d8f490f18fa8fd77b1e78e4739f3e2bf0d600a703869da916a204d50184",
        "w24": "4d1a012741cde567e83f5069a6c22fc63e83d71fc3e3543bc034ba0bf4a99ba1",
    ]

    private static let punctuationWithoutStrokes: Set<Character> = ["。", "、", "！", "？", "ー"]
    private static let smallKanaWithoutStrokes: Set<Character> = Set("ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮ")

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

    private func kana(of token: SentenceToken) -> String {
        token.reading ?? token.surface
    }

    private func withoutSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "")
    }

    func testDecodesAtLeastOneHundredPromptsWithUniqueIDs() {
        XCTAssertGreaterThanOrEqual(prompts.count, 100)
        XCTAssertEqual(Set(prompts.map(\.id)).count, prompts.count)
    }

    func testEveryPromptIsASentencePrompt() {
        let store = WordPromptStore(prompts: prompts)
        XCTAssertEqual(store.sentencePrompts.map(\.id), prompts.map(\.id))
        for prompt in prompts {
            XCTAssertFalse(prompt.tokens?.isEmpty ?? true, prompt.id)
            XCTAssertFalse(prompt.translation?.trimmingCharacters(in: .whitespaces).isEmpty ?? true, prompt.id)
        }
    }

    func testTokensJoinToTheSentenceWithTheAnswerSubstituted() throws {
        for prompt in prompts {
            let tokens = try XCTUnwrap(prompt.tokens, prompt.id)
            let kanaBefore = withoutSpaces(prompt.before)
            let kanaAfter = withoutSpaces(prompt.after)
            var consumed = ""
            var targetIndex: Int?
            for (index, token) in tokens.enumerated() {
                if consumed == kanaBefore {
                    targetIndex = index
                    break
                }
                consumed += kana(of: token)
            }
            let index = try XCTUnwrap(targetIndex, "\(prompt.id): no token starts after the kana before the answer")
            XCTAssertEqual(tokens[index].surface, prompt.answer, prompt.id)
            XCTAssertEqual(tokens[index].reading, prompt.reading, prompt.id)
            let writtenBefore = tokens[..<index].map(\.surface).joined()
            let remaining = tokens[(index + 1)...]
            XCTAssertEqual(remaining.map(kana(of:)).joined(), kanaAfter, prompt.id)
            let writtenAfter = remaining.map(\.surface).joined()
            XCTAssertEqual(tokens.map(\.surface).joined(), writtenBefore + prompt.answer + writtenAfter, prompt.id)
        }
    }

    func testKanaSentenceMatchesTokenReadings() throws {
        for prompt in prompts {
            let tokens = try XCTUnwrap(prompt.tokens, prompt.id)
            XCTAssertEqual(withoutSpaces(prompt.sentence), tokens.map(kana(of:)).joined(), prompt.id)
        }
    }

    func testReadingsAreSetExactlyForTokensWithKanji() throws {
        for prompt in prompts {
            let tokens = try XCTUnwrap(prompt.tokens, prompt.id)
            for token in tokens {
                XCTAssertEqual(token.reading != nil, containsKanji(token.surface), "\(prompt.id): \(token.surface)")
                if let reading = token.reading {
                    XCTAssertFalse(containsKanji(reading), "\(prompt.id): \(reading)")
                    XCTAssertFalse(reading.isEmpty, "\(prompt.id): \(token.surface)")
                }
            }
        }
    }

    func testEveryWrittenCharacterHasStrokeData() throws {
        let allowed = Self.punctuationWithoutStrokes.union(Self.smallKanaWithoutStrokes)
        for prompt in prompts {
            let tokens = try XCTUnwrap(prompt.tokens, prompt.id)
            for character in tokens.map(\.surface).joined() where !allowed.contains(character) {
                let kanji = kanjiStore.lookup(character: character)
                XCTAssertNotNil(kanji, "\(prompt.id): \(character) has no stroke data")
                XCTAssertFalse(kanji?.strokes.isEmpty ?? true, "\(prompt.id): \(character) has no strokes")
            }
        }
    }

    func testOriginalPromptRevisionsAreUnchanged() {
        let byID = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, $0) })
        for (id, revision) in Self.legacyRevisions {
            XCTAssertEqual(byID[id]?.revision, revision, id)
        }
    }

    func testAnswersAreUnique() {
        let answers = prompts.map(\.answer)
        XCTAssertEqual(Set(answers).count, answers.count)
    }
}
