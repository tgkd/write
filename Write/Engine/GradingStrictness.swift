import CoreGraphics

enum GradingStrictness: String, CaseIterable, Codable, Sendable {
    case lenient
    case normal
    case strict

    var leniency: CGFloat {
        switch self {
        case .lenient: return 1.3
        case .normal: return 1.0
        case .strict: return 0.8
        }
    }

    var displayName: String {
        switch self {
        case .lenient: return "Lenient"
        case .normal: return "Normal"
        case .strict: return "Strict"
        }
    }

    static func nearest(toLeniency leniency: CGFloat) -> GradingStrictness {
        allCases.min { abs($0.leniency - leniency) < abs($1.leniency - leniency) } ?? .normal
    }
}
