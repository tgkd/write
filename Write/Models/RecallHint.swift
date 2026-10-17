enum RecallHint: Int, Comparable, Sendable {
    case unused
    case character
    case strokes

    var next: RecallHint? {
        RecallHint(rawValue: rawValue + 1)
    }

    var recordName: String {
        switch self {
        case .unused: return "none"
        case .character: return "character"
        case .strokes: return "strokes"
        }
    }

    static func < (lhs: RecallHint, rhs: RecallHint) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
