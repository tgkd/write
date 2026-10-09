enum WritingScript: Hashable, Sendable {
    case kanji
    case hiragana
    case katakana

    init(codePoint: String) {
        let value = Int(codePoint, radix: 16) ?? 0
        if (0x3041...0x309F).contains(value) {
            self = .hiragana
        } else if (0x30A0...0x30FF).contains(value) {
            self = .katakana
        } else {
            self = .kanji
        }
    }

    var displayName: String {
        switch self {
        case .kanji: return "Kanji"
        case .hiragana: return "Hiragana"
        case .katakana: return "Katakana"
        }
    }
}
