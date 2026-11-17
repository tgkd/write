import XCTest
import UIKit
@testable import Write

@MainActor
final class ColorSettingsTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "ColorSettingsTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    func testMissingInkColorLoadsSumi() {
        XCTAssertEqual(AppSettings(defaults: defaults).inkColor, .sumi)
    }

    func testStoredInkColorSurvivesReload() {
        AppSettings(defaults: defaults).inkColor = .vermilion
        XCTAssertEqual(AppSettings(defaults: defaults).inkColor, .vermilion)
    }

    func testUnknownInkColorLoadsSumi() {
        defaults.set("gold", forKey: AppSettings.inkColorKey)
        XCTAssertEqual(AppSettings(defaults: defaults).inkColor, .sumi)
    }

    func testStoredGuidePaletteLoadsMatchingCase() {
        let expected: [String: ColorPalette] = ["warm": .warm, "cool": .cool, "ink": .ink]
        for (raw, palette) in expected {
            defaults.set(raw, forKey: "colorPalette")
            let settings = AppSettings(defaults: defaults)
            XCTAssertEqual(settings.colorPalette, palette, raw)
            XCTAssertEqual(settings.inkColor, .sumi, raw)
        }
    }

    func testInkColorsContrastWithBackgroundInBothModes() {
        for ink in InkColor.allCases {
            let light = Self.luminance(Self.resolve(ink.color, .light))
            let dark = Self.luminance(Self.resolve(ink.color, .dark))
            XCTAssertGreaterThanOrEqual(1 - light, 0.4, "\(ink) light")
            XCTAssertGreaterThanOrEqual(dark, 0.4, "\(ink) dark")
        }
    }

    func testMonoGuideIsVisibleInDarkMode() {
        for total in [1, 2, 5, 12, 24] {
            for index in 0..<total {
                let color = Self.resolve(ColorPalette.ink.strokeOrderColor(index: index, total: total), .dark)
                XCTAssertGreaterThanOrEqual(0.3 * Self.luminance(color), 0.10, "\(index)/\(total)")
            }
        }
    }

    func testMonoGuideInLightModeKeepsTodaysColors() {
        for total in [1, 2, 5, 12] {
            for index in 0..<total {
                let brightness: CGFloat = total > 1 ? 0.15 + CGFloat(index) / CGFloat(total - 1) * 0.40 : 0.15
                let expected = Self.components(UIColor(hue: 0, saturation: 0, brightness: brightness, alpha: 1))
                let actual = Self.components(Self.resolve(ColorPalette.ink.strokeOrderColor(index: index, total: total), .light))
                for (a, e) in zip(actual, expected) {
                    XCTAssertEqual(a, e, accuracy: 0.0001, "\(index)/\(total)")
                }
            }
        }
    }

    func testNotebookCellTakesAndUpdatesInkColorInPlace() throws {
        let cell = NotebookCellView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        cell.configurePractice(
            showCrosshair: true,
            allowedTouchTypes: [.direct, .pencil],
            pressureSensitivity: .off,
            tiltSensitivity: .off,
            smoothingStrength: .medium,
            brushThickness: .medium,
            inkColor: .indigo
        )
        let canvas = try XCTUnwrap(cell.canvasView)
        Self.assertSameColor(canvas.strokeColor, InkColor.indigo.color)

        cell.updatePracticeSettings(
            showCrosshair: true,
            allowedTouchTypes: [.direct, .pencil],
            brushConfig: BrushStroke.Config(pressure: .off, tilt: .off, smoothing: .medium, thickness: .medium),
            inkColor: .vermilion
        )
        XCTAssertTrue(cell.canvasView === canvas)
        Self.assertSameColor(canvas.strokeColor, InkColor.vermilion.color)
    }

    private static func assertSameColor(_ actual: UIColor, _ expected: UIColor, file: StaticString = #filePath, line: UInt = #line) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let a = components(resolve(actual, style))
            let e = components(resolve(expected, style))
            for (x, y) in zip(a, e) {
                XCTAssertEqual(x, y, accuracy: 0.0001, file: file, line: line)
            }
        }
    }

    private static func resolve(_ color: UIColor, _ style: UIUserInterfaceStyle) -> UIColor {
        color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    private static func components(_ color: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    private static func luminance(_ color: UIColor) -> CGFloat {
        let c = components(color)
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }
}
