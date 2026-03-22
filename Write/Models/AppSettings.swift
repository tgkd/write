import UIKit

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

    // MARK: - iPad Settings

    @Published var pressureSensitivity: PressureSensitivity {
        didSet { UserDefaults.standard.set(pressureSensitivity.rawValue, forKey: "pressureSensitivity") }
    }

    @Published var allowFingerDrawing: Bool {
        didSet { UserDefaults.standard.set(allowFingerDrawing, forKey: "allowFingerDrawing") }
    }

    @Published var showCrosshairGuidelines: Bool {
        didSet { UserDefaults.standard.set(showCrosshairGuidelines, forKey: "showCrosshairGuidelines") }
    }

    @Published var cellsPerRow: Int {
        didSet { UserDefaults.standard.set(cellsPerRow, forKey: "cellsPerRow") }
    }

    static let canvasScaleRange: ClosedRange<CGFloat> = 0.4...1.0
    static let canvasScaleStep: CGFloat = 0.1

    @Published var practiceCanvasScale: CGFloat {
        didSet { UserDefaults.standard.set(Double(practiceCanvasScale), forKey: "practiceCanvasScale") }
    }

    init() {
        let storedWidth = UserDefaults.standard.double(forKey: "maskPathWidth")
        self.maskPathWidth = storedWidth > 0 ? CGFloat(storedWidth) : Self.defaultMaskPathWidth

        let storedPalette = UserDefaults.standard.string(forKey: "colorPalette") ?? ""
        self.colorPalette = ColorPalette(rawValue: storedPalette) ?? .warm

        let storedCount = UserDefaults.standard.integer(forKey: "sessionCount")
        self.sessionCount = storedCount > 0 ? storedCount : 10

        let storedSensitivity = UserDefaults.standard.string(forKey: "pressureSensitivity") ?? ""
        self.pressureSensitivity = PressureSensitivity(rawValue: storedSensitivity) ?? .medium

        self.allowFingerDrawing = UserDefaults.standard.object(forKey: "allowFingerDrawing") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "allowFingerDrawing")

        self.showCrosshairGuidelines = UserDefaults.standard.object(forKey: "showCrosshairGuidelines") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "showCrosshairGuidelines")

        let storedCells = UserDefaults.standard.integer(forKey: "cellsPerRow")
        self.cellsPerRow = storedCells > 0 ? storedCells : 8

        let storedScale = UserDefaults.standard.double(forKey: "practiceCanvasScale")
        self.practiceCanvasScale = storedScale > 0 ? CGFloat(storedScale) : 0.7
    }

    var derivedLeniency: CGFloat {
        sqrt(maskPathWidth / Self.defaultMaskPathWidth)
    }

    var validationConfig: ValidationConfig {
        var config = ValidationConfig.standard
        config.leniency = derivedLeniency
        return config
    }

    var allowedTouchTypes: Set<UITouch.TouchType> {
        if DeviceContext.isIPad && !allowFingerDrawing {
            return [.pencil]
        }
        return [.direct, .pencil]
    }
}
