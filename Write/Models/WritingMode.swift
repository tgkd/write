import SwiftUI

enum WritingMode: String, CaseIterable, Identifiable {
    case free
    case trace
    case empty

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .free: return "Free"
        case .trace: return "Trace"
        case .empty: return "Empty"
        }
    }
}
