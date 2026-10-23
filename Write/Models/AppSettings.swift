import UIKit

@MainActor
final class AppSettings: ObservableObject {

    static let defaultMaskPathWidth: CGFloat = 5.0
    static let maskPathWidthRange: ClosedRange<CGFloat> = 3...14
    static let gradingStrictnessKey = "gradingStrictness"
    static let showWordPracticeKey = "showWordPractice"
    static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    static let recallCueOrderKey = "recallCueOrder"

    private let defaults: UserDefaults

    @Published var gradingStrictness: GradingStrictness {
        didSet { defaults.set(gradingStrictness.rawValue, forKey: Self.gradingStrictnessKey) }
    }

    @Published var maskPathWidth: CGFloat {
        didSet { defaults.set(Double(maskPathWidth), forKey: "maskPathWidth") }
    }

    @Published var colorPalette: ColorPalette {
        didSet { defaults.set(colorPalette.rawValue, forKey: "colorPalette") }
    }

    @Published var sessionCount: Int {
        didSet { defaults.set(sessionCount, forKey: "sessionCount") }
    }

    @Published var practiceMode: PracticeMode {
        didSet { defaults.set(practiceMode.rawValue, forKey: "practiceMode") }
    }

    @Published var showWordPractice: Bool {
        didSet { defaults.set(showWordPractice, forKey: Self.showWordPracticeKey) }
    }

    @Published var iCloudSyncEnabled: Bool {
        didSet { defaults.set(iCloudSyncEnabled, forKey: Self.iCloudSyncEnabledKey) }
    }

    @Published var recallCueOrder: RecallCueOrder {
        didSet { defaults.set(recallCueOrder.rawValue, forKey: Self.recallCueOrderKey) }
    }

    // MARK: - iPad Settings

    @Published var pressureSensitivity: PressureSensitivity {
        didSet { defaults.set(pressureSensitivity.rawValue, forKey: "pressureSensitivity") }
    }

    @Published var tiltSensitivity: TiltSensitivity {
        didSet { defaults.set(tiltSensitivity.rawValue, forKey: "tiltSensitivity") }
    }

    @Published var smoothingStrength: SmoothingStrength {
        didSet { defaults.set(smoothingStrength.rawValue, forKey: "smoothingStrength") }
    }

    @Published var brushThickness: BrushThickness {
        didSet { defaults.set(brushThickness.rawValue, forKey: "brushThickness") }
    }

    @Published var allowFingerDrawing: Bool {
        didSet { defaults.set(allowFingerDrawing, forKey: "allowFingerDrawing") }
    }

    @Published var handedness: Handedness {
        didSet { defaults.set(handedness.rawValue, forKey: "handedness") }
    }

    @Published var showCrosshairGuidelines: Bool {
        didSet { defaults.set(showCrosshairGuidelines, forKey: "showCrosshairGuidelines") }
    }

    @Published var cellsPerRow: Int {
        didSet { defaults.set(cellsPerRow, forKey: "cellsPerRow") }
    }

    static let canvasScaleRange: ClosedRange<CGFloat> = 0.4...1.0
    static let canvasScaleStep: CGFloat = 0.1

    @Published var practiceCanvasScale: CGFloat {
        didSet { defaults.set(Double(practiceCanvasScale), forKey: "practiceCanvasScale") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.gradingStrictness = Self.storedStrictness(in: defaults)

        let storedWidth = defaults.double(forKey: "maskPathWidth")
        self.maskPathWidth = storedWidth > 0 ? CGFloat(storedWidth) : Self.defaultMaskPathWidth

        let storedPalette = defaults.string(forKey: "colorPalette") ?? ""
        self.colorPalette = ColorPalette(rawValue: storedPalette) ?? .warm

        let storedCount = defaults.integer(forKey: "sessionCount")
        self.sessionCount = storedCount > 0 ? storedCount : 10

        let storedMode = defaults.string(forKey: "practiceMode") ?? ""
        self.practiceMode = PracticeMode(rawValue: storedMode) ?? .trace

        self.showWordPractice = defaults.bool(forKey: Self.showWordPracticeKey)

        self.iCloudSyncEnabled = defaults.object(forKey: Self.iCloudSyncEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Self.iCloudSyncEnabledKey)

        let storedCueOrder = defaults.string(forKey: Self.recallCueOrderKey) ?? ""
        self.recallCueOrder = RecallCueOrder(rawValue: storedCueOrder) ?? .meaningsFirst

        let storedSensitivity = defaults.string(forKey: "pressureSensitivity") ?? ""
        self.pressureSensitivity = PressureSensitivity(rawValue: storedSensitivity) ?? .medium

        let storedTilt = defaults.string(forKey: "tiltSensitivity") ?? ""
        self.tiltSensitivity = TiltSensitivity(rawValue: storedTilt) ?? .low

        let storedSmoothing = defaults.string(forKey: "smoothingStrength") ?? ""
        self.smoothingStrength = SmoothingStrength(rawValue: storedSmoothing) ?? .auto

        let storedThickness = defaults.string(forKey: "brushThickness") ?? ""
        self.brushThickness = BrushThickness(rawValue: storedThickness) ?? .medium

        self.allowFingerDrawing = defaults.object(forKey: "allowFingerDrawing") == nil
            ? true
            : defaults.bool(forKey: "allowFingerDrawing")

        let storedHandedness = defaults.string(forKey: "handedness") ?? ""
        self.handedness = Handedness(rawValue: storedHandedness) ?? .right

        self.showCrosshairGuidelines = defaults.object(forKey: "showCrosshairGuidelines") == nil
            ? true
            : defaults.bool(forKey: "showCrosshairGuidelines")

        let storedCells = defaults.integer(forKey: "cellsPerRow")
        self.cellsPerRow = storedCells > 0 ? storedCells : 8

        let storedScale = defaults.double(forKey: "practiceCanvasScale")
        self.practiceCanvasScale = storedScale > 0 ? CGFloat(storedScale) : 0.7
    }

    static func storedStrictness(in defaults: UserDefaults) -> GradingStrictness {
        if let raw = defaults.string(forKey: gradingStrictnessKey) {
            let stored = GradingStrictness(rawValue: raw) ?? .normal
            if stored.rawValue != raw {
                defaults.set(stored.rawValue, forKey: gradingStrictnessKey)
            }
            return stored
        }
        let width = CGFloat(defaults.double(forKey: "maskPathWidth"))
        let migrated = width > 0
            ? GradingStrictness.nearest(toLeniency: sqrt(width / defaultMaskPathWidth))
            : .strict
        defaults.set(migrated.rawValue, forKey: gradingStrictnessKey)
        return migrated
    }

    var validationConfig: ValidationConfig {
        var config = ValidationConfig.standard
        config.leniency = gradingStrictness.leniency
        return config
    }

    var allowedTouchTypes: Set<UITouch.TouchType> {
        if DeviceContext.isIPad && !allowFingerDrawing {
            return [.pencil]
        }
        return [.direct, .pencil]
    }
}
