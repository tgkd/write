import Foundation

struct RecallCue: Equatable, Sendable {
    enum Kind: Hashable, Sendable {
        case romaji
        case onYomi
        case kunYomi
        case meanings
    }

    struct Line: Hashable, Sendable {
        let kind: Kind
        let text: String
    }

    let primary: [Line]
    let secondary: [Line]

    init(kanji: KanjiData, order: RecallCueOrder) {
        let readings = Self.readingLines(for: kanji)
        let meanings = Self.meaningLines(for: kanji)
        switch order {
        case .meaningsFirst:
            primary = meanings.isEmpty ? readings : meanings
            secondary = meanings.isEmpty ? [] : readings
        case .readingsFirst:
            primary = readings.isEmpty ? meanings : readings
            secondary = readings.isEmpty ? [] : meanings
        }
    }

    var lines: [Line] {
        primary + secondary
    }

    static func readingLines(for kanji: KanjiData) -> [Line] {
        var lines: [Line] = []
        if let romaji = cueRomaji(for: kanji) {
            lines.append(Line(kind: .romaji, text: romaji))
        }
        if let on = kanji.onYomi, !on.isEmpty {
            lines.append(Line(kind: .onYomi, text: on.joined(separator: "、 ")))
        }
        if let kun = kanji.kunYomi, !kun.isEmpty {
            lines.append(Line(kind: .kunYomi, text: kun.joined(separator: "、 ")))
        }
        return lines
    }

    static func cueRomaji(for kanji: KanjiData) -> String? {
        guard let romaji = kanji.romaji, !romaji.isEmpty else {
            return nil
        }
        guard let distinct = distinctRomaji[kanji.text] else {
            return romaji
        }
        return "\(romaji) (\(distinct))"
    }

    private static let distinctRomaji = ["ぢ": "di", "づ": "du", "ヂ": "di", "ヅ": "du"]

    static func meaningLines(for kanji: KanjiData) -> [Line] {
        let meanings = (kanji.meanings ?? []).prefix(RecallEligibility.meaningsShown)
        if meanings.isEmpty {
            return []
        }
        return [Line(kind: .meanings, text: meanings.joined(separator: ", "))]
    }
}
