import Foundation

enum SpokenReading {
    static let maxOnReadings = 2
    static let maxKunReadings = 2
    static let separator = "、"

    static func text(for kanji: KanjiData) -> String? {
        switch kanji.script {
        case .hiragana, .katakana:
            return String(kanji.character)
        case .kanji:
            let on = cleaned(kanji.onYomi ?? [], limit: maxOnReadings)
            let kun = cleaned(kanji.kunYomi ?? [], limit: maxKunReadings)
            let readings = unique(on + kun)
            if readings.isEmpty {
                return nil
            }
            return readings.joined(separator: separator)
        }
    }

    static func clean(_ reading: String) -> String {
        var result = ""
        var depth = 0
        for character in reading {
            switch character {
            case "(", "（":
                depth += 1
            case ")", "）":
                depth = max(0, depth - 1)
            default:
                if depth == 0 {
                    result.append(character)
                }
            }
        }
        result = result.replacingOccurrences(of: ".", with: "")
        result = result.trimmingCharacters(in: .whitespaces)
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-－"))
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func cleaned(_ readings: [String], limit: Int) -> [String] {
        Array(unique(readings.map(clean).filter { !$0.isEmpty }).prefix(limit))
    }

    private static func unique(_ readings: [String]) -> [String] {
        var seen: Set<String> = []
        return readings.filter { seen.insert($0).inserted }
    }
}
