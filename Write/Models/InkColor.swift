import UIKit

enum InkColor: String, CaseIterable, Sendable {
    case sumi
    case indigo
    case vermilion

    var displayName: String {
        switch self {
        case .sumi: return String(localized: "Sumi")
        case .indigo: return String(localized: "Indigo")
        case .vermilion: return String(localized: "Vermilion")
        }
    }

    var color: UIColor {
        switch self {
        case .sumi:
            return .label
        case .indigo:
            return Self.adaptive(
                light: UIColor(red: 0.11, green: 0.18, blue: 0.50, alpha: 1),
                dark: UIColor(red: 0.60, green: 0.70, blue: 1.00, alpha: 1)
            )
        case .vermilion:
            return Self.adaptive(
                light: UIColor(red: 0.75, green: 0.13, blue: 0.05, alpha: 1),
                dark: UIColor(red: 1.00, green: 0.45, blue: 0.33, alpha: 1)
            )
        }
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}
