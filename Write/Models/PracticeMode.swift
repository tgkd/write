import Foundation

enum PracticeMode: String, CaseIterable, Sendable {
    case trace
    case strokeByStroke
    case copy = "freeDraw"

    var displayName: String {
        switch self {
        case .trace: return String(localized: "Trace")
        case .strokeByStroke: return String(localized: "Guided")
        case .copy: return String(localized: "Copy")
        }
    }

    var summary: String {
        switch self {
        case .trace: return String(localized: "Write over the full guide.")
        case .strokeByStroke: return String(localized: "Follow one stroke at a time.")
        case .copy: return String(localized: "Copy the character without a guide.")
        }
    }

    /// Alpha for all non-current ghost strokes (nil = hidden).
    var ghostStrokeAlpha: CGFloat? {
        switch self {
        case .trace: return 0.15
        case .strokeByStroke: return nil
        case .copy: return nil
        }
    }

    /// Alpha for the current expected stroke (nil = hidden).
    var currentStrokeAlpha: CGFloat? {
        switch self {
        case .trace: return 0.5
        case .strokeByStroke: return 0.5
        case .copy: return nil
        }
    }

    /// Whether to animate the current stroke reveal via strokeEnd.
    var animateStrokeReveal: Bool {
        switch self {
        case .strokeByStroke: return true
        default: return false
        }
    }

    /// Consecutive misses before auto-hint (nil = no auto-hint).
    var autoHintAfterMisses: Int? {
        switch self {
        case .strokeByStroke: return 3
        default: return nil
        }
    }
}
