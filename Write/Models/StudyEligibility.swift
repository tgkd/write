import Foundation

struct StudyEligibility: Sendable {
    private struct Cue: Hashable {
        let script: WritingScript
        let romaji: String?
        let onYomi: [String]
        let kunYomi: [String]
        let meanings: [String]
        let strokeCount: Int
    }

    static let meaningsShown = 3

    let ambiguousCodePoints: Set<String>

    init(ambiguousCodePoints: Set<String> = []) {
        self.ambiguousCodePoints = ambiguousCodePoints
    }

    init(kanji: [KanjiData]) {
        var groups: [Cue: [String]] = [:]
        for item in kanji where Self.hasCue(item) {
            groups[Self.cue(for: item), default: []].append(item.codePoint)
        }
        ambiguousCodePoints = Set(groups.values.filter { $0.count > 1 }.joined())
    }

    func isEligible(_ kanji: KanjiData) -> Bool {
        Self.hasCue(kanji) && !ambiguousCodePoints.contains(kanji.codePoint)
    }

    static func hasCue(_ kanji: KanjiData) -> Bool {
        switch kanji.script {
        case .hiragana, .katakana:
            return !(kanji.romaji ?? "").isEmpty
        case .kanji:
            let readings = (kanji.onYomi ?? []) + (kanji.kunYomi ?? [])
            return !readings.isEmpty || !(kanji.meanings ?? []).isEmpty
        }
    }

    private static func cue(for kanji: KanjiData) -> Cue {
        Cue(
            script: kanji.script,
            romaji: kanji.romaji,
            onYomi: kanji.onYomi ?? [],
            kunYomi: kanji.kunYomi ?? [],
            meanings: Array((kanji.meanings ?? []).prefix(meaningsShown)),
            strokeCount: kanji.strokes.count
        )
    }
}
