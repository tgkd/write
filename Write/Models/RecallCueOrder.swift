import Foundation

enum RecallCueOrder: String, CaseIterable, Sendable {
    case meaningsFirst
    case readingsFirst

    var displayName: String {
        switch self {
        case .meaningsFirst:
            return String(localized: "Meanings first")
        case .readingsFirst:
            return String(localized: "Readings first")
        }
    }
}
