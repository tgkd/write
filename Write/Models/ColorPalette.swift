import UIKit

enum ColorPalette: String, CaseIterable, Sendable {
    case warm
    case cool
    case ink

    var displayName: String {
        switch self {
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .ink: return "Ink"
        }
    }

    func strokeOrderColor(index: Int, total: Int) -> UIColor {
        switch self {
        case .warm:
            return warmColor(index: index, total: total)
        case .cool:
            return coolColor(index: index, total: total)
        case .ink:
            return inkColor(index: index, total: total)
        }
    }

    var acceptedColor: UIColor {
        switch self {
        case .warm: return .systemGreen
        case .cool: return .systemCyan
        case .ink: return UIColor(hue: 0.5, saturation: 0.4, brightness: 0.5, alpha: 1)
        }
    }

    var rejectedColor: UIColor {
        switch self {
        case .warm: return .systemRed
        case .cool: return .systemPink
        case .ink: return UIColor(hue: 0.08, saturation: 0.5, brightness: 0.6, alpha: 1)
        }
    }

    // MARK: - Private

    private func warmColor(index: Int, total: Int) -> UIColor {
        guard total > 1 else {
            return UIColor(hue: 0.0, saturation: 0.60, brightness: 0.75, alpha: 1)
        }
        let hue = CGFloat(index) / CGFloat(total - 1) * 0.33
        return UIColor(hue: hue, saturation: 0.60, brightness: 0.75, alpha: 1)
    }

    private func coolColor(index: Int, total: Int) -> UIColor {
        guard total > 1 else {
            return UIColor(hue: 0.55, saturation: 0.55, brightness: 0.80, alpha: 1)
        }
        let hue = 0.55 + CGFloat(index) / CGFloat(total - 1) * 0.20
        return UIColor(hue: hue, saturation: 0.55, brightness: 0.80, alpha: 1)
    }

    private func inkColor(index: Int, total: Int) -> UIColor {
        guard total > 1 else {
            return UIColor(hue: 0, saturation: 0, brightness: 0.15, alpha: 1)
        }
        let brightness = 0.15 + CGFloat(index) / CGFloat(total - 1) * 0.40
        return UIColor(hue: 0, saturation: 0, brightness: brightness, alpha: 1)
    }
}
