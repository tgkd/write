enum RecallHint: Int, Comparable, Sendable {
    case unused
    case character
    case strokes

    var next: RecallHint? {
        RecallHint(rawValue: rawValue + 1)
    }

    static func < (lhs: RecallHint, rhs: RecallHint) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
