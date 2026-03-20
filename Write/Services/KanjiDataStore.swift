import Foundation

final class KanjiDataStore: Sendable {
    private let kanjiMap: [String: KanjiData]
    let allCodePoints: [String]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "kanji_strokes", withExtension: "json") else {
            assertionFailure("kanji_strokes.json not found in bundle")
            kanjiMap = [:]
            allCodePoints = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: KanjiData].self, from: data)
            kanjiMap = decoded
            allCodePoints = decoded.keys.sorted()
        } catch {
            assertionFailure("Failed to load kanji data: \(error)")
            kanjiMap = [:]
            allCodePoints = []
        }
    }

    init(data: Data) throws {
        let decoded = try JSONDecoder().decode([String: KanjiData].self, from: data)
        kanjiMap = decoded
        allCodePoints = decoded.keys.sorted()
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

    func search(query: String) -> [KanjiData] {
        let q = query.lowercased()
        return allCodePoints.compactMap { kanjiMap[$0] }.filter { kanji in
            if let meanings = kanji.meanings {
                if meanings.contains(where: { $0.lowercased().contains(q) }) { return true }
            }
            if let on = kanji.onYomi {
                if on.contains(where: { $0.contains(query) }) { return true }
            }
            if let kun = kanji.kunYomi {
                if kun.contains(where: { $0.contains(query) }) { return true }
            }
            return false
        }
    }

    func randomKanji(jlpt: Int?, count: Int) -> [KanjiData] {
        let pool = allCodePoints.compactMap { kanjiMap[$0] }
            .filter { jlpt == nil || $0.jlpt == jlpt }
        return Array(pool.shuffled().prefix(count))
    }

    var count: Int {
        kanjiMap.count
    }
}
