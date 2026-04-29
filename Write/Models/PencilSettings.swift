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

enum TiltSensitivity: String, CaseIterable, Sendable {
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

enum SmoothingStrength: String, CaseIterable, Sendable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    /// (minCutoff, beta) for OneEuroFilter. dCutoff stays at 10.
    var filterParams: (minCutoff: CGFloat, beta: CGFloat) {
        switch self {
        case .low: return (0.8, 0.3)
        case .medium: return (1.5, 0.5)
        case .high: return (3.0, 0.8)
        }
    }
}

enum Handedness: String, CaseIterable, Sendable {
    case right
    case left

    var displayName: String {
        switch self {
        case .right: return "Right"
        case .left: return "Left"
        }
    }
}

enum BrushThickness: String, CaseIterable, Sendable {
    case thin
    case medium
    case thick

    var displayName: String {
        switch self {
        case .thin: return "Thin"
        case .medium: return "Medium"
        case .thick: return "Thick"
        }
    }

    var widthRange: (min: CGFloat, max: CGFloat) {
        switch self {
        case .thin: return (1.0, 5.0)
        case .medium: return (1.5, 8.0)
        case .thick: return (2.5, 12.0)
        }
    }
}
