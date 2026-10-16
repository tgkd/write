import Foundation

extension BrushStroke.Config {
    /// Builds a brush config from the user-facing settings enums.
    init(
        pressure: PressureSensitivity,
        tilt: TiltSensitivity,
        smoothing: SmoothingStrength,
        thickness: BrushThickness
    ) {
        self.init()
        pressureSensitivity = pressure
        tiltSensitivity = tilt
        self.smoothing = smoothing
        applySmoothingParameters(of: smoothing)
        let widthRange = thickness.widthRange
        minWidth = widthRange.min
        maxWidth = widthRange.max
    }

    func resolved(forPencil isPencil: Bool) -> BrushStroke.Config {
        var config = self
        config.widthModel = isPencil ? .speed : .finger
        if smoothing == .auto {
            config.applySmoothingParameters(of: smoothing.effective(forPencil: isPencil))
        }
        return config
    }

    private mutating func applySmoothingParameters(of smoothing: SmoothingStrength) {
        let filterParams = smoothing.filterParams
        filterMinCutoff = filterParams.minCutoff
        filterBeta = filterParams.beta
        let centerline = smoothing.centerlineParams
        centerlineRadius = centerline.radius
        centerlineMaxShift = centerline.maxShift
    }
}

enum PressureSensitivity: String, CaseIterable, Sendable {
    case off
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .off: return String(localized: "Off")
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
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
        case .off: return String(localized: "Off")
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
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
    case auto
    case low
    case medium
    case high

    static let validation: SmoothingStrength = .medium

    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
        }
    }

    func effective(forPencil isPencil: Bool) -> SmoothingStrength {
        guard self == .auto else {
            return self
        }
        return isPencil ? .medium : .high
    }

    /// (minCutoff, beta) for OneEuroFilter. dCutoff stays at 10.
    /// Lower minCutoff/beta = heavier filtering, so "high" smoothing maps to the LOW tuple.
    var filterParams: (minCutoff: CGFloat, beta: CGFloat) {
        switch self {
        case .auto: return SmoothingStrength.medium.filterParams
        case .low: return (3.0, 0.8)
        case .medium: return (1.5, 0.5)
        case .high: return (0.8, 0.3)
        }
    }

    var centerlineParams: (radius: Int, maxShift: CGFloat) {
        switch self {
        case .auto: return SmoothingStrength.medium.centerlineParams
        case .low: return (1, 0.75)
        case .medium: return (2, 1.25)
        case .high: return (3, 2.0)
        }
    }
}

enum Handedness: String, CaseIterable, Sendable {
    case right
    case left

    var displayName: String {
        switch self {
        case .right: return String(localized: "Right")
        case .left: return String(localized: "Left")
        }
    }
}

enum BrushThickness: String, CaseIterable, Sendable {
    case thin
    case medium
    case thick

    var displayName: String {
        switch self {
        case .thin: return String(localized: "Thin")
        case .medium: return String(localized: "Medium")
        case .thick: return String(localized: "Thick")
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
