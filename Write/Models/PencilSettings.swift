import Foundation

enum PressureSensitivity: String, CaseIterable, Sendable {
    case off
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var blendFactor: CGFloat {
        switch self {
        case .off: return 0
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.9
        }
    }
}

