enum PracticeFocus: String, CaseIterable, Sendable {
    case new
    case review

    var kind: SessionKind {
        switch self {
        case .new: return .practice
        case .review: return .recall
        }
    }
}
