import Foundation

enum PracticeMode: String, CaseIterable, Sendable {
    case trace
    case strokeByStroke
    case freeDraw

    var displayName: String {
        switch self {
        case .trace: return "Trace"
        case .strokeByStroke: return "Guided"
        case .freeDraw: return "Free"
        }
    }

    /// Alpha for all non-current ghost strokes (nil = hidden).
    var ghostStrokeAlpha: CGFloat? {
        switch self {
        case .trace: return 0.3
        case .strokeByStroke: return nil
        case .freeDraw: return nil
        }
    }

    /// Alpha for the current expected stroke (nil = hidden).
    var currentStrokeAlpha: CGFloat? {
        switch self {
        case .trace: return 0.5
        case .strokeByStroke: return 0.5
        case .freeDraw: return nil
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
