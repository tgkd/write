import XCTest
@testable import Write

// MARK: - PointSampler Tests

final class PointSamplerTests: XCTestCase {

    func testSamplePointsFromArray() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]
        let sampled = PointSampler.sample(points: points, count: 5)

        XCTAssertEqual(sampled.count, 5)
        XCTAssertEqual(sampled[0].x, 0, accuracy: 0.01)
        XCTAssertEqual(sampled[4].x, 100, accuracy: 0.01)
        XCTAssertEqual(sampled[2].x, 50, accuracy: 0.01)
    }

    func testSamplePreservesEndpoints() {
        let points = [CGPoint(x: 10, y: 20), CGPoint(x: 50, y: 30), CGPoint(x: 90, y: 80)]
        let sampled = PointSampler.sample(points: points, count: 50)

        XCTAssertEqual(sampled.first!.x, 10, accuracy: 0.01)
        XCTAssertEqual(sampled.first!.y, 20, accuracy: 0.01)
        XCTAssertEqual(sampled.last!.x, 90, accuracy: 0.01)
        XCTAssertEqual(sampled.last!.y, 80, accuracy: 0.01)
    }

    func testSampleEquallySpaced() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]
        let sampled = PointSampler.sample(points: points, count: 11)

        for i in 0..<sampled.count {
            XCTAssertEqual(sampled[i].x, CGFloat(i * 10), accuracy: 0.01)
            XCTAssertEqual(sampled[i].y, 0, accuracy: 0.01)
        }
    }

    func testSampleFromCGPath() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))

        let sampled = PointSampler.sample(path: path, count: 5)
        XCTAssertEqual(sampled.count, 5)
        XCTAssertEqual(sampled[0].x, 0, accuracy: 0.01)
        XCTAssertEqual(sampled[4].x, 100, accuracy: 0.01)
    }

    func testSampleFromCurvedPath() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(
            to: CGPoint(x: 100, y: 100),
            control1: CGPoint(x: 0, y: 50),
            control2: CGPoint(x: 50, y: 100)
        )

        let sampled = PointSampler.sample(path: path, count: 20)
        XCTAssertEqual(sampled.count, 20)
        XCTAssertEqual(sampled.first!.x, 0, accuracy: 0.5)
        XCTAssertEqual(sampled.first!.y, 0, accuracy: 0.5)
        XCTAssertEqual(sampled.last!.x, 100, accuracy: 0.5)
        XCTAssertEqual(sampled.last!.y, 100, accuracy: 0.5)
    }

    func testSampleTooFewPoints() {
        let single = [CGPoint(x: 5, y: 5)]
        XCTAssertEqual(PointSampler.sample(points: single, count: 10).count, 1)

        let empty: [CGPoint] = []
        XCTAssertEqual(PointSampler.sample(points: empty, count: 10).count, 0)
    }

    func testFlattenPathHandlesQuadCurve() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 50, y: 50))

        let flat = PointSampler.flattenPath(path)
        XCTAssertTrue(flat.count > 2)
        XCTAssertEqual(flat.first!.x, 0, accuracy: 0.01)
        XCTAssertEqual(flat.last!.x, 100, accuracy: 0.01)
    }

    func testSampleCountMatchesRequested() {
        let points = [
            CGPoint(x: 0, y: 0), CGPoint(x: 30, y: 40),
            CGPoint(x: 60, y: 20), CGPoint(x: 100, y: 80)
        ]
        for count in [3, 10, 50, 100] {
            let sampled = PointSampler.sample(points: points, count: count)
            XCTAssertEqual(sampled.count, count)
        }
    }
}

// MARK: - ProcrustesNormalizer Tests

final class ProcrustesNormalizerTests: XCTestCase {

    func testCentroidComputation() {
        let points = [
            CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)
        ]
        let c = ProcrustesNormalizer.centroid(of: points)
        XCTAssertEqual(c.x, 5, accuracy: 0.01)
        XCTAssertEqual(c.y, 5, accuracy: 0.01)
    }

    func testCentroidOfEmpty() {
        let c = ProcrustesNormalizer.centroid(of: [])
        XCTAssertEqual(c.x, 0)
        XCTAssertEqual(c.y, 0)
    }

    func testTranslateToOrigin() {
        let points = [CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 40)]
        let centered = ProcrustesNormalizer.translateToOrigin(points)
        let centroid = ProcrustesNormalizer.centroid(of: centered)
        XCTAssertEqual(centroid.x, 0, accuracy: 0.001)
        XCTAssertEqual(centroid.y, 0, accuracy: 0.001)
    }

    func testScaleToUnit() {
        let points = [CGPoint(x: -5, y: 0), CGPoint(x: 5, y: 0)]
        let (scaled, size) = ProcrustesNormalizer.scaleToUnit(points)
        XCTAssertEqual(size, 5, accuracy: 0.01)

        let rms = ProcrustesNormalizer.rmsSize(of: scaled)
        XCTAssertEqual(rms, 1.0, accuracy: 0.01)
    }

    func testRotation() {
        let points = [CGPoint(x: 1, y: 0)]
        let rotated = ProcrustesNormalizer.rotate(points, by: .pi / 2)
        XCTAssertEqual(rotated[0].x, 0, accuracy: 0.01)
        XCTAssertEqual(rotated[0].y, 1, accuracy: 0.01)
    }

    func testInvarianceToTranslation() {
        let original = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)]
        let shifted = [CGPoint(x: 100, y: 200), CGPoint(x: 110, y: 210)]

        let dist = ProcrustesNormalizer.procrustesDistance(source: original, target: shifted)
        XCTAssertEqual(dist, 0, accuracy: 0.01)
    }

    func testInvarianceToScale() {
        let small = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]
        let big = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)]

        let dist = ProcrustesNormalizer.procrustesDistance(source: small, target: big)
        XCTAssertEqual(dist, 0, accuracy: 0.01)
    }

    func testInvarianceToRotation() {
        let horizontal = [CGPoint(x: -1, y: 0), CGPoint(x: 1, y: 0)]
        let vertical = [CGPoint(x: 0, y: -1), CGPoint(x: 0, y: 1)]

        let dist = ProcrustesNormalizer.procrustesDistance(source: horizontal, target: vertical)
        XCTAssertEqual(dist, 0, accuracy: 0.01)
    }

    func testDifferentShapesHaveHighDistance() {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0), CGPoint(x: 10, y: 0)]
        let vShape = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 10), CGPoint(x: 10, y: 0)]

        let dist = ProcrustesNormalizer.procrustesDistance(source: line, target: vShape)
        XCTAssertGreaterThan(dist, 0.1)
    }

    func testOptimalRotationIdentity() {
        let points = [CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1)]
        let angle = ProcrustesNormalizer.optimalRotation(from: points, to: points)
        XCTAssertEqual(angle, 0, accuracy: 0.01)
    }

    func testOptimalRotation90Degrees() {
        let source = [CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0)]
        let target = [CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: -1)]

        let angle = ProcrustesNormalizer.optimalRotation(from: source, to: target)
        XCTAssertEqual(angle, .pi / 2, accuracy: 0.01)
    }
}

// MARK: - FrechetDistance Tests

final class FrechetDistanceTests: XCTestCase {

    func testIdenticalCurvesZeroDistance() {
        let curve = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 5), CGPoint(x: 10, y: 0)]
        let dist = FrechetDistance.compute(between: curve, and: curve)
        XCTAssertEqual(dist, 0, accuracy: 0.001)
    }

    func testParallelLinesDistance() {
        let line1 = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]
        let line2 = [CGPoint(x: 0, y: 5), CGPoint(x: 10, y: 5)]

        let dist = FrechetDistance.compute(between: line1, and: line2)
        XCTAssertEqual(dist, 5, accuracy: 0.01)
    }

    func testBackwardsStrokeScoresPoorly() {
        let forward = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50), CGPoint(x: 100, y: 0)]
        let backward = [CGPoint(x: 100, y: 0), CGPoint(x: 50, y: 50), CGPoint(x: 0, y: 0)]

        let forwardDist = FrechetDistance.compute(between: forward, and: forward)
        let backwardDist = FrechetDistance.compute(between: backward, and: forward)

        XCTAssertLessThan(forwardDist, backwardDist,
            "Forward stroke should have lower Frechet distance than backwards")
    }

    func testRecursiveAndIterativeMatch() {
        let p = [CGPoint(x: 0, y: 0), CGPoint(x: 30, y: 50), CGPoint(x: 60, y: 20), CGPoint(x: 100, y: 80)]
        let q = [CGPoint(x: 5, y: 3), CGPoint(x: 35, y: 45), CGPoint(x: 55, y: 25), CGPoint(x: 95, y: 85)]

        let recursive = FrechetDistance.compute(between: p, and: q)
        let iterative = FrechetDistance.computeIterative(between: p, and: q)

        XCTAssertEqual(recursive, iterative, accuracy: 0.001)
    }

    func testEmptyCurvesReturnInfinity() {
        let empty: [CGPoint] = []
        let nonempty = [CGPoint(x: 0, y: 0)]

        XCTAssertEqual(FrechetDistance.compute(between: empty, and: nonempty), .infinity)
        XCTAssertEqual(FrechetDistance.compute(between: nonempty, and: empty), .infinity)
    }

    func testSinglePointCurves() {
        let p = [CGPoint(x: 0, y: 0)]
        let q = [CGPoint(x: 3, y: 4)]

        let dist = FrechetDistance.compute(between: p, and: q)
        XCTAssertEqual(dist, 5, accuracy: 0.01)
    }

    func testDissimilarCurvesHighDistance() {
        let straight = (0..<20).map { CGPoint(x: CGFloat($0) * 5, y: 0) }
        let zigzag = (0..<20).map { CGPoint(x: CGFloat($0) * 5, y: $0 % 2 == 0 ? 0 : 50) }

        let dist = FrechetDistance.compute(between: straight, and: zigzag)
        XCTAssertGreaterThan(dist, 40)
    }

    func testSymmetry() {
        let p = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 20)]
        let q = [CGPoint(x: 5, y: 5), CGPoint(x: 15, y: 25)]

        let d1 = FrechetDistance.compute(between: p, and: q)
        let d2 = FrechetDistance.compute(between: q, and: p)
        XCTAssertEqual(d1, d2, accuracy: 0.001)
    }
}

// MARK: - StrokeValidator Tests

final class StrokeValidatorTests: XCTestCase {

    let canvasSize = CGSize(width: 300, height: 300)

    func testIdenticalStrokeScoresHigh() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 50, y: 50))
        path.addLine(to: CGPoint(x: 250, y: 250))

        let refPoints = PointSampler.sample(path: path, count: 50)

        let result = StrokeValidator.validate(
            userPoints: refPoints,
            referencePathData: "M18.25,18.25 L90,90",
            canvasSize: canvasSize
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.accepted)
        XCTAssertGreaterThan(result!.score, 0.5)
    }

    func testVeryDifferentStrokeRejected() {
        let userPoints = [
            CGPoint(x: 50, y: 250), CGPoint(x: 150, y: 50), CGPoint(x: 250, y: 250)
        ]

        let result = StrokeValidator.validate(
            userPoints: userPoints,
            referencePathData: "M18,18 C18,50 50,90 90,90",
            canvasSize: canvasSize
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.accepted)
        XCTAssertLessThan(result!.score, 0.8)
    }

    func testStrokeIdentificationFindsCorrectMatch() {
        let strokes = [
            KanjiStroke(strokeNumber: 1, pathData: "M18,18 L90,18", strokeType: nil),
            KanjiStroke(strokeNumber: 2, pathData: "M18,18 L18,90", strokeType: nil),
            KanjiStroke(strokeNumber: 3, pathData: "M18,90 L90,90", strokeType: nil),
        ]

        let scale = min(canvasSize.width, canvasSize.height) / 109.0
        let userPoints = [
            CGPoint(x: 18 * scale, y: 18 * scale),
            CGPoint(x: 90 * scale, y: 18 * scale)
        ]

        let result = StrokeValidator.identifyStroke(
            userPoints: userPoints,
            referenceStrokes: strokes,
            unmatchedIndices: Set(0..<strokes.count),
            canvasSize: canvasSize,
            expectedStrokeIndex: 0
        )

        XCTAssertEqual(result.matchedStrokeIndex, 0)
        XCTAssertTrue(result.correctOrder)
    }

    func testStrokeOrderValidation() {
        let strokes = [
            KanjiStroke(strokeNumber: 1, pathData: "M18,18 L90,18", strokeType: nil),
            KanjiStroke(strokeNumber: 2, pathData: "M18,50 L90,50", strokeType: nil),
        ]

        let scale = min(canvasSize.width, canvasSize.height) / 109.0
        let userPointsStroke2 = [
            CGPoint(x: 18 * scale, y: 50 * scale),
            CGPoint(x: 90 * scale, y: 50 * scale)
        ]

        let result = StrokeValidator.identifyStroke(
            userPoints: userPointsStroke2,
            referenceStrokes: strokes,
            unmatchedIndices: Set(0..<strokes.count),
            canvasSize: canvasSize,
            expectedStrokeIndex: 0
        )

        XCTAssertEqual(result.matchedStrokeIndex, 1)
        XCTAssertFalse(result.correctOrder, "Drawing stroke 2 when stroke 1 is expected should be wrong order")
    }

    func testNoMatchReturnsZeroScore() {
        let strokes = [
            KanjiStroke(strokeNumber: 1, pathData: "M10,10 L10,100", strokeType: nil),
        ]

        let farAwayPoints = [
            CGPoint(x: 290, y: 290),
            CGPoint(x: 295, y: 295)
        ]

        let result = StrokeValidator.identifyStroke(
            userPoints: farAwayPoints,
            referenceStrokes: strokes,
            unmatchedIndices: [0],
            canvasSize: canvasSize,
            expectedStrokeIndex: 0
        )

        XCTAssertEqual(result.score, 0)
        XCTAssertFalse(result.accepted)
    }

    func testConfigurableThresholds() {
        let lenient = ValidationConfig.lenient
        let strict = ValidationConfig.strict

        XCTAssertGreaterThan(lenient.shapeThreshold, strict.shapeThreshold)
        XCTAssertGreaterThan(lenient.leniency, strict.leniency)
    }

    func testValidationResultScoreRange() {
        let userPoints = [CGPoint(x: 50, y: 50), CGPoint(x: 250, y: 50)]

        let result = StrokeValidator.validate(
            userPoints: userPoints,
            referencePathData: "M18,18 L90,18",
            canvasSize: canvasSize
        )

        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.score, 0)
        XCTAssertLessThanOrEqual(result!.score, 1)
    }

    func testEmptyUnmatchedIndices() {
        let strokes = [
            KanjiStroke(strokeNumber: 1, pathData: "M18,18 L90,18", strokeType: nil),
        ]

        let result = StrokeValidator.identifyStroke(
            userPoints: [CGPoint(x: 50, y: 50), CGPoint(x: 250, y: 50)],
            referenceStrokes: strokes,
            unmatchedIndices: [],
            canvasSize: canvasSize,
            expectedStrokeIndex: 0
        )

        XCTAssertEqual(result.score, 0)
        XCTAssertNil(result.matchedStrokeIndex)
    }
}
