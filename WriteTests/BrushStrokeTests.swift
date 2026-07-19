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
        // In a One Euro filter, LOWER minCutoff/beta = MORE smoothing, so the
        // "high" smoothing setting must have the smallest parameter values.
        let low = SmoothingStrength.low.filterParams
        let medium = SmoothingStrength.medium.filterParams
        let high = SmoothingStrength.high.filterParams

        XCTAssertLessThan(high.minCutoff, medium.minCutoff)
        XCTAssertLessThan(medium.minCutoff, low.minCutoff)
        XCTAssertLessThan(high.beta, medium.beta)
        XCTAssertLessThan(medium.beta, low.beta)
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

// MARK: - LiveRenderer equivalence tests

final class BrushStrokeLiveRendererTests: XCTestCase {

    /// A long curved stroke: 120 samples on a sine wave, 8pt apart in x.
    private func makeLongStroke() -> [BrushStroke.Sample] {
        (0..<120).map { i in
            BrushStroke.Sample(
                point: CGPoint(x: CGFloat(i) * 8, y: 200 + 40 * sin(CGFloat(i) * 0.3)),
                timestamp: TimeInterval(i) * 0.008,
                force: nil,
                altitude: nil
            )
        }
    }

    /// The incremental live path must stay a close approximation of the full
    /// rebuild at every point during the stroke (checked via bounding boxes).
    func testLivePathTracksFullRebuild() {
        let config = BrushStroke.Config()
        let samples = makeLongStroke()
        var renderer = BrushStroke.LiveRenderer(config: config)

        // 120 samples with tailWindow 16 guarantees several freeze steps.
        for (i, sample) in samples.enumerated() {
            renderer.append(sample)

            let checkpoints = [20, 50, 80, 119]
            guard checkpoints.contains(i) else { continue }

            let live = renderer.currentPath().boundingBoxOfPath
            let full = BrushStroke.createPath(from: Array(samples[0...i]), config: config)
                .boundingBoxOfPath

            XCTAssertEqual(live.minX, full.minX, accuracy: 1.5, "minX at sample \(i)")
            XCTAssertEqual(live.minY, full.minY, accuracy: 1.5, "minY at sample \(i)")
            XCTAssertEqual(live.maxX, full.maxX, accuracy: 1.5, "maxX at sample \(i)")
            XCTAssertEqual(live.maxY, full.maxY, accuracy: 1.5, "maxY at sample \(i)")
        }
    }

    func testRefineUpdatesUnfrozenSample() {
        var config = BrushStroke.Config()
        config.pressureSensitivity = .high

        var renderer = BrushStroke.LiveRenderer(config: config)
        let samples = (0..<10).map { i in
            BrushStroke.Sample(
                point: CGPoint(x: CGFloat(i) * 30, y: 100),
                timestamp: TimeInterval(i) * 0.02,
                force: 0.05,
                altitude: nil
            )
        }
        for sample in samples { renderer.append(sample) }
        let before = renderer.currentPath().boundingBoxOfPath.height

        for i in 0..<10 {
            renderer.refine(rawIndex: i, force: 0.9, altitude: nil)
        }
        let after = renderer.currentPath().boundingBoxOfPath.height

        XCTAssertGreaterThan(after, before + 0.5,
            "Refining force on unfrozen samples must widen the live ribbon")
    }
}

// MARK: - BrushStroke pressure-blend tests

final class BrushStrokePressureTests: XCTestCase {

    /// Horizontal stroke with a fixed normalized force (0…1) on every sample.
    private func makeHorizontalStroke(force: CGFloat?) -> [BrushStroke.Sample] {
        var samples: [BrushStroke.Sample] = []
        var t: TimeInterval = 0
        for i in 0..<12 {
            let x = CGFloat(i) * 30 + 50
            samples.append(BrushStroke.Sample(
                point: CGPoint(x: x, y: 100),
                timestamp: t,
                force: force,
                altitude: nil
            ))
            t += 0.02
        }
        return samples
    }

    private func ribbonHeight(force: CGFloat?, sensitivity: PressureSensitivity) -> CGFloat {
        var config = BrushStroke.Config()
        config.pressureSensitivity = sensitivity
        return BrushStroke.createPath(from: makeHorizontalStroke(force: force), config: config)
            .boundingBoxOfPath.height
    }

    func testPressureOffIgnoresForce() {
        XCTAssertEqual(
            ribbonHeight(force: 0.9, sensitivity: .off),
            ribbonHeight(force: nil, sensitivity: .off),
            accuracy: 0.5
        )
    }

    func testPressureHighWidthMonotonicWithForce() {
        let light = ribbonHeight(force: 0.1, sensitivity: .high)
        let medium = ribbonHeight(force: 0.5, sensitivity: .high)
        let heavy = ribbonHeight(force: 0.9, sensitivity: .high)

        XCTAssertGreaterThan(medium, light)
        XCTAssertGreaterThan(heavy, medium)
    }

    func testTypicalWritingForceReachesMidWidth() {
        // Average handwriting force ≈ 0.24 normalized. The response curve must
        // land it around mid-width; the old linear mapping left it near minimum.
        let height = ribbonHeight(force: 0.24, sensitivity: .high)
        let config = BrushStroke.Config()
        let midWidth = (config.minWidth + config.maxWidth) / 2

        XCTAssertGreaterThan(height, midWidth * 0.8,
            "Typical writing force should produce a clearly visible width response")
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
