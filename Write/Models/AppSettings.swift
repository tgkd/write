import Foundation
import CoreGraphics

@MainActor
final class AppSettings: ObservableObject {

    static let defaultMaskPathWidth: CGFloat = 5.0
    static let maskPathWidthRange: ClosedRange<CGFloat> = 3...14

    @Published var maskPathWidth: CGFloat {
        didSet { UserDefaults.standard.set(Double(maskPathWidth), forKey: "maskPathWidth") }
    }

    @Published var colorPalette: ColorPalette {
        didSet { UserDefaults.standard.set(colorPalette.rawValue, forKey: "colorPalette") }
    }

    @Published var sessionCount: Int {
        didSet { UserDefaults.standard.set(sessionCount, forKey: "sessionCount") }
    }

    init() {
        let storedWidth = UserDefaults.standard.double(forKey: "maskPathWidth")
        self.maskPathWidth = storedWidth > 0 ? CGFloat(storedWidth) : Self.defaultMaskPathWidth

        let storedPalette = UserDefaults.standard.string(forKey: "colorPalette") ?? ""
        self.colorPalette = ColorPalette(rawValue: storedPalette) ?? .warm

        let storedCount = UserDefaults.standard.integer(forKey: "sessionCount")
        self.sessionCount = storedCount > 0 ? storedCount : 10
    }

    var derivedLeniency: CGFloat {
        sqrt(maskPathWidth / Self.defaultMaskPathWidth)
    }

    var validationConfig: ValidationConfig {
        var config = ValidationConfig.standard
        config.leniency = derivedLeniency
        return config
    }
}
