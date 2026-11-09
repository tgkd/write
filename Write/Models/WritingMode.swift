import SwiftUI

enum WritingMode: String, CaseIterable, Identifiable {
    case free
    case trace
    case empty

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .free: return "Free"
        case .trace: return "By strokes · Trace"
        case .empty: return "By strokes · Empty"
        }
    }
}
