import XCTest
import CoreGraphics
@testable import Write

// MARK: - Preset round-trip tests

final class PencilSettingsPresetsTests: XCTestCase {

    func testSmoothingStrengthMediumMatchesHistoricalDefault() {
        // The historical hardcoded OneEuroFilter defaults were (1.5, 0.5).
        // .medium must preserve them so existing users see no behavior change.
        let params = SmoothingStrength.medium.filterParams
        XCTAssertEqual(params.minCutoff, 1.5, accuracy: 0.0001)
        XCTAssertEqual(params.beta, 0.5, accuracy: 0.0001)
    }

    func testSmoothingStrengthOrderingMonotonic() {
        let low = SmoothingStrength.low.filterParams
        let medium = SmoothingStrength.medium.filterParams
        let high = SmoothingStrength.high.filterParams

        XCTAssertLessThan(low.minCutoff, medium.minCutoff)
        XCTAssertLessThan(medium.minCutoff, high.minCutoff)
        XCTAssertLessThan(low.beta, medium.beta)
        XCTAssertLessThan(medium.beta, high.beta)
    }

    func testBrushThicknessMediumMatchesHistoricalDefault() {
        // The historical hardcoded BrushStroke.Config defaults were (1.5, 8.0).
        let range = BrushThickness.medium.widthRange
        XCTAssertEqual(range.min, 1.5, accuracy: 0.0001)
        XCTAssertEqual(range.max, 8.0, accuracy: 0.0001)
    }

    func testBrushThicknessOrderingMonotonic() {
        let thin = BrushThickness.thin.widthRange
        let medium = BrushThickness.medium.widthRange
        let thick = BrushThickness.thick.widthRange

        XCTAssertLessThan(thin.max, medium.max)
        XCTAssertLessThan(medium.max, thick.max)
    }

    func testTiltSensitivityBlendFactorsMatchPressureSensitivity() {
        // Tilt mirrors pressure: same blend factors so users get consistent
        // mental model across the two settings.
        XCTAssertEqual(TiltSensitivity.off.blendFactor, PressureSensitivity.off.blendFactor)
        XCTAssertEqual(TiltSensitivity.low.blendFactor, PressureSensitivity.low.blendFactor)
        XCTAssertEqual(TiltSensitivity.medium.blendFactor, PressureSensitivity.medium.blendFactor)
        XCTAssertEqual(TiltSensitivity.high.blendFactor, PressureSensitivity.high.blendFactor)
    }
}

// MARK: - BrushStroke tilt-blend tests

final class BrushStrokeTiltTests: XCTestCase {

    /// Build a horizontal stroke along y=100 with a fixed altitude on every sample.
    private func makeHorizontalStroke(altitude: CGFloat?) -> [BrushStroke.Sample] {
        // 12 samples spaced ~30pt apart so distance filter (4pt) keeps them all,
        // and the stroke is long enough that taper at start/end (15%) leaves a
        // stable middle region for measurement.
        var samples: [BrushStroke.Sample] = []
        var t: TimeInterval = 0
        for i in 0..<12 {
            let x = CGFloat(i) * 30 + 50
            samples.append(BrushStroke.Sample(
                point: CGPoint(x: x, y: 100),
                timestamp: t,
                force: nil,
                altitude: altitude
            ))
            t += 0.02   // ~50 Hz, gives a moderate speed
        }
        return samples
    }

    func testTiltOffIgnoresAltitude() {
        var config = BrushStroke.Config()
        config.tiltSensitivity = .off

        let withTilt = BrushStroke.createPath(from: makeHorizontalStroke(altitude: 0), config: config)
        let withoutTilt = BrushStroke.createPath(from: makeHorizontalStroke(altitude: nil), config: config)

        // With tilt off, altitude must not affect ribbon geometry — bounding boxes match.
        XCTAssertEqual(withTilt.boundingBoxOfPath.height, withoutTilt.boundingBoxOfPath.height, accuracy: 0.5)
    }

    func testTiltHighFlatPencilProducesWiderStroke() {
        var config = BrushStroke.Config()
        config.tiltSensitivity = .high

        // altitude ~ 0 means pencil lying flat → max calligraphy width.
        let flat = BrushStroke.createPath(from: makeHorizontalStroke(altitude: 0), config: config)
        // altitude ~ π/2 means pencil straight up → min calligraphy width.
        let vertical = BrushStroke.createPath(from: makeHorizontalStroke(altitude: .pi / 2), config: config)

        let flatHeight = flat.boundingBoxOfPath.height
        let verticalHeight = vertical.boundingBoxOfPath.height

        XCTAssertGreaterThan(flatHeight, verticalHeight,
            "Flat pencil (altitude≈0) should produce a wider ribbon than vertical pencil (altitude≈π/2)")
    }

    func testTiltContributesProportionallyToBlendFactor() {
        // .low (0.3 blend) should produce a smaller delta than .high (0.9 blend).
        var lowConfig = BrushStroke.Config()
        lowConfig.tiltSensitivity = .low

        var highConfig = BrushStroke.Config()
        highConfig.tiltSensitivity = .high

        let lowFlat = BrushStroke.createPath(from: makeHorizontalStroke(altitude: 0), config: lowConfig).boundingBoxOfPath.height
        let lowVertical = BrushStroke.createPath(from: makeHorizontalStroke(altitude: .pi / 2), config: lowConfig).boundingBoxOfPath.height

        let highFlat = BrushStroke.createPath(from: makeHorizontalStroke(altitude: 0), config: highConfig).boundingBoxOfPath.height
        let highVertical = BrushStroke.createPath(from: makeHorizontalStroke(altitude: .pi / 2), config: highConfig).boundingBoxOfPath.height

        let lowDelta = lowFlat - lowVertical
        let highDelta = highFlat - highVertical

        XCTAssertGreaterThan(highDelta, lowDelta,
            "Higher tilt sensitivity must produce a larger width delta between flat and vertical pencil")
    }
}
