import UIKit

@MainActor
final class AppSettings: ObservableObject {

    static let defaultMaskPathWidth: CGFloat = 5.0
    static let maskPathWidthRange: ClosedRange<CGFloat> = 3...14
    static let gradingStrictnessKey = "gradingStrictness"
    static let showRejectionReasonsKey = "showRejectionReasons"
    static let showPracticeGridKey = "showPracticeGrid"
    static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    static let recallCueOrderKey = "recallCueOrder"
    static let writingModeKey = "writingMode"
    static let practiceFocusKey = "practiceFocus"
    static let lastReviewAttemptAtKey = "lastReviewAttemptAt"
    static let inkColorKey = "inkColor"
    nonisolated static let pencilDoubleTapEnabledKey = "pencilDoubleTapEnabled"
    nonisolated static let pencilSqueezeEnabledKey = "pencilSqueezeEnabled"

    private let defaults: UserDefaults

    @Published var gradingStrictness: GradingStrictness {
        didSet { defaults.set(gradingStrictness.rawValue, forKey: Self.gradingStrictnessKey) }
    }

    @Published var showRejectionReasons: Bool {
        didSet { defaults.set(showRejectionReasons, forKey: Self.showRejectionReasonsKey) }
    }

    @Published var showPracticeGrid: Bool {
        didSet { defaults.set(showPracticeGrid, forKey: Self.showPracticeGridKey) }
    }

    @Published var maskPathWidth: CGFloat {
        didSet { defaults.set(Double(maskPathWidth), forKey: "maskPathWidth") }
    }

    @Published var colorPalette: ColorPalette {
        didSet { defaults.set(colorPalette.rawValue, forKey: "colorPalette") }
    }

    @Published var inkColor: InkColor {
        didSet { defaults.set(inkColor.rawValue, forKey: Self.inkColorKey) }
    }

    @Published var sessionCount: Int {
        didSet { defaults.set(sessionCount, forKey: "sessionCount") }
    }

    @Published var practiceMode: PracticeMode {
        didSet { defaults.set(practiceMode.rawValue, forKey: "practiceMode") }
    }

    @Published var writingMode: WritingMode {
        didSet { defaults.set(writingMode.rawValue, forKey: Self.writingModeKey) }
    }

    @Published var practiceFocus: PracticeFocus {
        didSet { defaults.set(practiceFocus.rawValue, forKey: Self.practiceFocusKey) }
    }

    @Published var iCloudSyncEnabled: Bool {
        didSet { defaults.set(iCloudSyncEnabled, forKey: Self.iCloudSyncEnabledKey) }
    }

    @Published var recallCueOrder: RecallCueOrder {
        didSet { defaults.set(recallCueOrder.rawValue, forKey: Self.recallCueOrderKey) }
    }

    @Published var lastReviewAttemptAt: Date? {
        didSet { defaults.set(lastReviewAttemptAt, forKey: Self.lastReviewAttemptAtKey) }
    }

    @Published var isReviewRequestPending = false

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

    @Published var pencilDoubleTapEnabled: Bool {
        didSet { defaults.set(pencilDoubleTapEnabled, forKey: Self.pencilDoubleTapEnabledKey) }
    }

    @Published var pencilSqueezeEnabled: Bool {
        didSet { defaults.set(pencilSqueezeEnabled, forKey: Self.pencilSqueezeEnabledKey) }
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

    static let writingCellSideRange: ClosedRange<CGFloat> = 120...320
    static let writingCellSideStep: CGFloat = 20
    static let defaultWritingCellSide: CGFloat = 200

    @Published var writingCellSide: CGFloat {
        didSet { defaults.set(Double(writingCellSide), forKey: "writingCellSide") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.gradingStrictness = Self.storedStrictness(in: defaults)

        self.showRejectionReasons = defaults.object(forKey: Self.showRejectionReasonsKey) == nil
            ? true
            : defaults.bool(forKey: Self.showRejectionReasonsKey)

        self.showPracticeGrid = defaults.object(forKey: Self.showPracticeGridKey) == nil
            ? true
            : defaults.bool(forKey: Self.showPracticeGridKey)

        let storedWidth = defaults.double(forKey: "maskPathWidth")
        self.maskPathWidth = storedWidth > 0 ? CGFloat(storedWidth) : Self.defaultMaskPathWidth

        let storedPalette = defaults.string(forKey: "colorPalette") ?? ""
        self.colorPalette = ColorPalette(rawValue: storedPalette) ?? .warm

        let storedInk = defaults.string(forKey: Self.inkColorKey) ?? ""
        self.inkColor = InkColor(rawValue: storedInk) ?? .sumi

        let storedCount = defaults.integer(forKey: "sessionCount")
        self.sessionCount = storedCount > 0 ? storedCount : 10

        let storedMode = defaults.string(forKey: "practiceMode") ?? ""
        self.practiceMode = PracticeMode(rawValue: storedMode) ?? .trace

        self.writingMode = WritingMode(rawValue: defaults.string(forKey: Self.writingModeKey) ?? "") ?? .free
        self.practiceFocus = PracticeFocus(rawValue: defaults.string(forKey: Self.practiceFocusKey) ?? "") ?? .new

        self.iCloudSyncEnabled = defaults.object(forKey: Self.iCloudSyncEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Self.iCloudSyncEnabledKey)

        let storedCueOrder = defaults.string(forKey: Self.recallCueOrderKey) ?? ""
        self.recallCueOrder = RecallCueOrder(rawValue: storedCueOrder) ?? .meaningsFirst
        self.lastReviewAttemptAt = defaults.object(forKey: Self.lastReviewAttemptAtKey) as? Date

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

        self.pencilDoubleTapEnabled = Self.isPencilDoubleTapEnabled(in: defaults)
        self.pencilSqueezeEnabled = Self.isPencilSqueezeEnabled(in: defaults)

        let storedHandedness = defaults.string(forKey: "handedness") ?? ""
        self.handedness = Handedness(rawValue: storedHandedness) ?? .right

        self.showCrosshairGuidelines = defaults.object(forKey: "showCrosshairGuidelines") == nil
            ? true
            : defaults.bool(forKey: "showCrosshairGuidelines")

        let storedCells = defaults.integer(forKey: "cellsPerRow")
        self.cellsPerRow = storedCells > 0 ? storedCells : 8

        let storedScale = defaults.double(forKey: "practiceCanvasScale")
        self.practiceCanvasScale = storedScale > 0 ? CGFloat(storedScale) : 0.7

        let storedCellSide = defaults.double(forKey: "writingCellSide")
        self.writingCellSide = storedCellSide > 0
            ? min(max(CGFloat(storedCellSide), Self.writingCellSideRange.lowerBound), Self.writingCellSideRange.upperBound)
            : Self.defaultWritingCellSide
    }

    nonisolated static func isPencilDoubleTapEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: pencilDoubleTapEnabledKey) == nil
            ? true
            : defaults.bool(forKey: pencilDoubleTapEnabledKey)
    }

    nonisolated static func isPencilSqueezeEnabled(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: pencilSqueezeEnabledKey)
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

    func rejectionNotice(for rejection: StrokeRejection?) -> String? {
        guard showRejectionReasons else {
            return nil
        }
        return rejection?.notice
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
