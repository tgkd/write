import Foundation

final class KanjiDataStore: Sendable {
    private let kanjiMap: [String: KanjiData]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "kanji_strokes", withExtension: "json") else {
            kanjiMap = [:]
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: KanjiData].self, from: data)
            kanjiMap = decoded
        } catch {
            kanjiMap = [:]
        }
    }

    init(data: Data) throws {
        let decoded = try JSONDecoder().decode([String: KanjiData].self, from: data)
        kanjiMap = decoded
    }

    func lookup(codePoint: String) -> KanjiData? {
        kanjiMap[codePoint.lowercased()]
    }

    func lookup(character: Character) -> KanjiData? {
        let scalars = character.unicodeScalars
        guard let scalar = scalars.first, scalars.count == 1 else { return nil }
        let hex = String(scalar.value, radix: 16, uppercase: false)
        return kanjiMap[hex]
    }

    var allCodePoints: [String] {
        Array(kanjiMap.keys).sorted()
    }

    var count: Int {
        kanjiMap.count
    }
}
