enum CharacterFilter: Hashable, Sendable {
    case all
    case hiragana
    case katakana
    case jlpt(Int)

    var label: String {
        switch self {
        case .all: return "All"
        case .hiragana: return "Hiragana"
        case .katakana: return "Katakana"
        case .jlpt(let level): return "N\(level)"
        }
    }

    func includes(_ kanji: KanjiData) -> Bool {
        switch self {
        case .all: return true
        case .hiragana: return kanji.script == .hiragana
        case .katakana: return kanji.script == .katakana
        case .jlpt(let level): return kanji.jlpt == level
        }
    }

    static let pickerOrder: [CharacterFilter] = [
        .all, .hiragana, .katakana, .jlpt(5), .jlpt(4), .jlpt(3), .jlpt(2), .jlpt(1)
    ]
}
