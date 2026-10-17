import XCTest
@testable import Write

final class StrokeBoundaryTests: XCTestCase {

    private struct EdgeCase {
        let label: String
        let side: CGFloat
        let samples: [[CGPoint]]
        let outward: CGVector
        let anchors: [StrokeAnchor]?

        var canvasSize: CGSize {
            CGSize(width: side, height: side)
        }

        func stroke(movedOutBy fraction: CGFloat) -> [CGPoint] {
            let distance = fraction * side
            return samples[0].map { CGPoint(x: $0.x + distance * outward.dx, y: $0.y + distance * outward.dy) }
        }
    }

    private let square = CGSize(width: 200, height: 200)
    private let tolerance = ValidationConfig.standard.boundaryTolerance
    private let withinTolerance: CGFloat = 0.018
    private let beyondTolerance: CGFloat = 0.022
    private let hookCanvases: [(side: CGFloat, hook: CGFloat)] = [(120, 4.5), (300, 9)]
    private let rightEdgeVertical = "M108.5,20 L108.5,80"

    private var edgeCases: [EdgeCase] {
        let edges: [(name: String, pathData: String, outward: CGVector)] = [
            ("left", "M0,50 L60,50", CGVector(dx: -1, dy: 0)),
            ("right", "M49,50 L109,50", CGVector(dx: 1, dy: 0)),
            ("top", "M50,0 L50,60", CGVector(dx: 0, dy: -1)),
            ("bottom", "M50,49 L50,109", CGVector(dx: 0, dy: 1)),
        ]
        return [CGFloat(120), 300, 1024].flatMap { side in
            edges.flatMap { edge -> [EdgeCase] in
                let samples = referenceSamples(edge.pathData, side: side)
                return ([nil, []] as [[StrokeAnchor]?]).map { anchors in
                    EdgeCase(
                        label: "\(edge.name) edge, \(Int(side)) pt, anchors \(anchors == nil ? "nil" : "[]")",
                        side: side,
                        samples: samples,
                        outward: edge.outward,
                        anchors: anchors
                    )
                }
            }
        }
    }

    private func referenceSamples(_ pathData: String, side: CGFloat) -> [[CGPoint]] {
        StrokeValidator.sampleReferenceStrokes(
            [KanjiStroke(strokeNumber: 1, pathData: pathData, strokeType: nil)],
            canvasSize: CGSize(width: side, height: side),
            sampleCount: ValidationConfig.standard.sampleCount
        )
    }

    private func excursion(_ points: [CGPoint], in size: CGSize? = nil) throws -> CGFloat {
        try XCTUnwrap(StrokeBoundary.excursion(of: points, canvasSize: size ?? square))
    }

    private func identify(
        _ points: [CGPoint],
        samples: [[CGPoint]],
        canvasSize: CGSize,
        anchors: [StrokeAnchor]?,
        config: ValidationConfig = .standard
    ) -> StrokeValidationResult {
        StrokeValidator.identifyStroke(
            userPoints: points,
            referenceSamples: samples,
            unmatchedIndices: Set(samples.indices),
            canvasSize: canvasSize,
            expectedStrokeIndex: 0,
            anchors: anchors,
            config: config
        )
    }

    private func identify(
        _ points: [CGPoint],
        _ edgeCase: EdgeCase,
        config: ValidationConfig = .standard
    ) -> StrokeValidationResult {
        identify(points, samples: edgeCase.samples, canvasSize: edgeCase.canvasSize, anchors: edgeCase.anchors, config: config)
    }

    private func segment(from start: CGPoint, to end: CGPoint, spacing: CGFloat = 1) -> [CGPoint] {
        let length = hypot(end.x - start.x, end.y - start.y)
        let steps = max(1, Int((length / spacing).rounded()))
        return (1...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
        }
    }

    private func withRightwardHook(_ body: [CGPoint], length: CGFloat) -> [CGPoint] {
        guard let end = body.last else {
            return body
        }
        return body + segment(from: end, to: CGPoint(x: end.x + length, y: end.y))
    }

    func testPointInsideTheCanvasHasNoExcursion() {
        XCTAssertEqual(StrokeBoundary.excursion(of: [CGPoint(x: 100, y: 100)], canvasSize: square), 0)
        XCTAssertEqual(StrokeBoundary.excursion(of: [CGPoint(x: 1, y: 199), CGPoint(x: 199, y: 1)], canvasSize: square), 0)
    }

    func testPointsOnTheEdgeHaveNoExcursion() {
        let onEdges = [
            CGPoint(x: 0, y: 80), CGPoint(x: 200, y: 80), CGPoint(x: 80, y: 0), CGPoint(x: 80, y: 200),
            CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 0), CGPoint(x: 200, y: 200), CGPoint(x: 0, y: 200),
        ]
        XCTAssertEqual(StrokeBoundary.excursion(of: onEdges, canvasSize: square), 0)
    }

    func testEmptyStrokeHasNoExcursion() {
        XCTAssertEqual(StrokeBoundary.excursion(of: [], canvasSize: square), 0)
    }

    func testExcursionBeyondEachEdgeIsNormalizedByTheSide() {
        let center = CGPoint(x: 100, y: 100)
        let cases: [(edge: String, point: CGPoint, expected: CGFloat)] = [
            ("left", CGPoint(x: -10, y: 100), 0.05),
            ("right", CGPoint(x: 206, y: 40), 0.03),
            ("top", CGPoint(x: 150, y: -4), 0.02),
            ("bottom", CGPoint(x: 20, y: 216), 0.08),
        ]
        for (edge, point, expected) in cases {
            XCTAssertEqual(try excursion([center, point, center]), expected, accuracy: 1e-9, edge)
        }
    }

    func testExcursionBeyondACornerIsTheEuclideanDistance() {
        let cases: [(corner: String, point: CGPoint, expected: CGFloat)] = [
            ("top left", CGPoint(x: -6, y: -8), 0.05),
            ("top right", CGPoint(x: 209, y: -12), 0.075),
            ("bottom right", CGPoint(x: 212, y: 216), 0.1),
            ("bottom left", CGPoint(x: -3, y: 204), 0.025),
        ]
        for (corner, point, expected) in cases {
            XCTAssertEqual(try excursion([point]), expected, accuracy: 1e-9, corner)
        }
    }

    func testStrokeThatExitsAndReentersReportsItsFarthestPoint() {
        let stroke = [
            CGPoint(x: 50, y: 50), CGPoint(x: 100, y: -10), CGPoint(x: 150, y: 50),
            CGPoint(x: 205, y: 100), CGPoint(x: 150, y: 150),
        ]
        XCTAssertEqual(try excursion(stroke), 0.05, accuracy: 1e-9)
        XCTAssertEqual(try excursion(Array(stroke.reversed())), 0.05, accuracy: 1e-9)
    }

    func testFarPointsAreNotClamped() {
        XCTAssertEqual(try excursion([CGPoint(x: -1000, y: 100)]), 5, accuracy: 1e-9)
    }

    func testNonSquareCanvasUsesItsShorterSide() {
        let wide = CGSize(width: 400, height: 200)
        XCTAssertEqual(try excursion([CGPoint(x: 350, y: 150)], in: wide), 0)
        XCTAssertEqual(try excursion([CGPoint(x: 410, y: 100)], in: wide), 0.05, accuracy: 1e-9)
        XCTAssertEqual(try excursion([CGPoint(x: 300, y: -10)], in: wide), 0.05, accuracy: 1e-9)

        let tall = CGSize(width: 200, height: 400)
        XCTAssertEqual(try excursion([CGPoint(x: 150, y: 350)], in: tall), 0)
        XCTAssertEqual(try excursion([CGPoint(x: 100, y: 410)], in: tall), 0.05, accuracy: 1e-9)
        XCTAssertEqual(try excursion([CGPoint(x: 220, y: 300)], in: tall), 0.1, accuracy: 1e-9)
    }

    func testNonFinitePointHasNoExcursion() {
        for value in [CGFloat.nan, .infinity, -.infinity] {
            let inside = CGPoint(x: 50, y: 50)
            XCTAssertNil(StrokeBoundary.excursion(of: [inside, CGPoint(x: value, y: 50)], canvasSize: square), "x \(value)")
            XCTAssertNil(StrokeBoundary.excursion(of: [CGPoint(x: 50, y: value), inside], canvasSize: square), "y \(value)")
        }
    }

    func testInvalidCanvasHasNoExcursion() {
        let sizes = [
            CGSize.zero,
            CGSize(width: 0, height: 200),
            CGSize(width: 200, height: 0),
            CGSize(width: -200, height: 200),
            CGSize(width: 200, height: -1),
            CGSize(width: CGFloat.nan, height: 200),
            CGSize(width: 200, height: CGFloat.nan),
            CGSize(width: 200, height: CGFloat.infinity),
            CGSize(width: -CGFloat.infinity, height: 200),
        ]
        for size in sizes {
            XCTAssertNil(StrokeBoundary.excursion(of: [CGPoint(x: 10, y: 10)], canvasSize: size), "\(size)")
            XCTAssertNil(StrokeBoundary.excursion(of: [], canvasSize: size), "\(size)")
        }
    }

    func testMatchingStrokeIsAcceptedInsideTheBoxAndWithinTheTolerance() {
        for edgeCase in edgeCases {
            for fraction in [0, withinTolerance] {
                let label = "\(edgeCase.label), moved out \(fraction)"
                let points = edgeCase.stroke(movedOutBy: fraction)
                XCTAssertEqual(try excursion(points, in: edgeCase.canvasSize), fraction, accuracy: 1e-6, label)

                let result = identify(points, edgeCase)
                XCTAssertTrue(result.accepted, label)
                XCTAssertEqual(result.geometryAccepted, true, label)
                XCTAssertEqual(result.evidence.boundaryPassed, true, label)
                XCTAssertEqual(result.matchedStrokeIndex, 0, label)
                XCTAssertTrue(result.correctOrder, label)
            }
        }
    }

    func testMatchingStrokeBeyondTheToleranceFailsOnlyTheBox() {
        for edgeCase in edgeCases {
            let label = edgeCase.label
            let points = edgeCase.stroke(movedOutBy: beyondTolerance)
            XCTAssertEqual(try excursion(points, in: edgeCase.canvasSize), beyondTolerance, accuracy: 1e-6, label)

            let inside = identify(edgeCase.stroke(movedOutBy: 0), edgeCase)
            let outside = identify(points, edgeCase)
            XCTAssertFalse(outside.accepted, label)
            XCTAssertEqual(outside.geometryAccepted, true, label)
            XCTAssertEqual(outside.evidence.boundaryPassed, false, label)
            XCTAssertTrue(outside.failedBoundary, label)
            XCTAssertEqual(outside.evidence.shapePassed, inside.evidence.shapePassed, label)
            XCTAssertEqual(outside.evidence.positionPassed, inside.evidence.positionPassed, label)
            XCTAssertEqual(outside.matchedStrokeIndex, 0, label)
            XCTAssertTrue(outside.correctOrder, label)
        }
    }

    func testBoxRuleOnlyOverridesAcceptance() {
        var unboxed = ValidationConfig.standard
        unboxed.boundaryTolerance = .infinity
        for edgeCase in edgeCases {
            let label = edgeCase.label
            let points = edgeCase.stroke(movedOutBy: beyondTolerance)
            let boxed = identify(points, edgeCase)
            let free = identify(points, edgeCase, config: unboxed)

            XCTAssertTrue(free.accepted, label)
            XCTAssertEqual(free.evidence.boundaryPassed, true, label)
            XCTAssertEqual(boxed.score, free.score, label)
            XCTAssertEqual(boxed.frechetDistance, free.frechetDistance, label)
            XCTAssertEqual(boxed.matchedStrokeIndex, free.matchedStrokeIndex, label)
            XCTAssertEqual(boxed.correctOrder, free.correctOrder, label)
            XCTAssertEqual(boxed.userCentroid, free.userCentroid, label)
            XCTAssertNotNil(boxed.anchor, label)
            XCTAssertEqual(boxed.anchor, free.anchor, label)
            var evidence = boxed.evidence
            evidence.boundaryPassed = true
            XCTAssertEqual(evidence, free.evidence, label)
        }
    }

    func testToleranceIsNotScaledByLeniency() {
        for strictness in GradingStrictness.allCases {
            var config = ValidationConfig.standard
            config.leniency = strictness.leniency
            for edgeCase in edgeCases {
                let label = "\(edgeCase.label), \(strictness.rawValue)"
                let within = identify(edgeCase.stroke(movedOutBy: withinTolerance), edgeCase, config: config)
                XCTAssertEqual(within.evidence.boundaryPassed, true, label)
                XCTAssertTrue(within.accepted, label)

                let beyond = identify(edgeCase.stroke(movedOutBy: beyondTolerance), edgeCase, config: config)
                XCTAssertEqual(beyond.evidence.boundaryPassed, false, label)
                XCTAssertEqual(beyond.geometryAccepted, true, label)
                XCTAssertFalse(beyond.accepted, label)
            }
        }
    }

    func testFallbackResultCarriesTheBoxVerdict() {
        let canvasSize = CGSize(width: 300, height: 300)
        let samples = referenceSamples("M10,10 L10,30", side: canvasSize.width)

        let inside = identify(
            [CGPoint(x: 290, y: 290), CGPoint(x: 295, y: 295)], samples: samples, canvasSize: canvasSize, anchors: []
        )
        XCTAssertNil(inside.matchedStrokeIndex)
        XCTAssertFalse(inside.accepted)
        XCTAssertEqual(inside.geometryAccepted, false)
        XCTAssertEqual(inside.evidence, StrokeEvidence(boundaryPassed: true))
        XCTAssertNil(inside.anchor)

        let outside = identify(
            [CGPoint(x: 290, y: 310), CGPoint(x: 295, y: 330)], samples: samples, canvasSize: canvasSize, anchors: []
        )
        XCTAssertNil(outside.matchedStrokeIndex)
        XCTAssertFalse(outside.accepted)
        XCTAssertEqual(outside.geometryAccepted, false)
        XCTAssertEqual(outside.evidence, StrokeEvidence(boundaryPassed: false))
        XCTAssertNil(outside.anchor)
    }

    func testInvalidInputNeverCountsAsInFrame() {
        let canvasSize = CGSize(width: 300, height: 300)
        let samples = referenceSamples("M20,50 L80,50", side: canvasSize.width)

        var broken = samples[0]
        broken.insert(CGPoint(x: CGFloat.nan, y: 150), at: 10)
        let nonFinite = identify(broken, samples: samples, canvasSize: canvasSize, anchors: nil)
        XCTAssertFalse(nonFinite.accepted)
        XCTAssertEqual(nonFinite.evidence.boundaryPassed, false)

        let degenerate = identify(
            samples[0], samples: samples, canvasSize: CGSize(width: canvasSize.width, height: 0), anchors: nil
        )
        XCTAssertEqual(degenerate.geometryAccepted, true)
        XCTAssertFalse(degenerate.accepted)
        XCTAssertEqual(degenerate.evidence.boundaryPassed, false)
    }

    func testTrimmedEndHookOutsideTheBoxPassesTheBoxCheck() {
        for (side, hook) in hookCanvases {
            let canvasSize = CGSize(width: side, height: side)
            let samples = referenceSamples(rightEdgeVertical, side: side)
            let raw = withRightwardHook(samples[0], length: hook)
            let trimmed = StrokeHookTrimmer.trim(raw, parameters: StrokeHookTrimmer.Parameters(canvasSize: canvasSize))

            for anchors in [nil, []] as [[StrokeAnchor]?] {
                let label = "\(Int(side)) pt, anchors \(anchors == nil ? "nil" : "[]")"
                XCTAssertGreaterThan(try excursion(raw, in: canvasSize), tolerance, label)
                XCTAssertLessThan(trimmed.count, raw.count, label)
                XCTAssertEqual(trimmed, samples[0], label)
                XCTAssertEqual(try excursion(trimmed, in: canvasSize), 0, label)

                let untrimmed = identify(raw, samples: samples, canvasSize: canvasSize, anchors: anchors)
                XCTAssertTrue(untrimmed.failedBoundary, label)
                XCTAssertFalse(untrimmed.accepted, label)

                let result = identify(trimmed, samples: samples, canvasSize: canvasSize, anchors: anchors)
                XCTAssertEqual(result.evidence.boundaryPassed, true, label)
                XCTAssertTrue(result.accepted, label)
                XCTAssertEqual(result.matchedStrokeIndex, 0, label)
            }
        }
    }

    func testTrimmedEndHookIsStillSubjectToTheOtherChecks() {
        for (side, hook) in hookCanvases {
            let canvasSize = CGSize(width: side, height: side)
            let samples = referenceSamples(rightEdgeVertical, side: side)
            let backwards = Array(samples[0].reversed())
            let raw = withRightwardHook(backwards, length: hook)
            let trimmed = StrokeHookTrimmer.trim(raw, parameters: StrokeHookTrimmer.Parameters(canvasSize: canvasSize))

            for anchors in [nil, []] as [[StrokeAnchor]?] {
                let label = "\(Int(side)) pt, anchors \(anchors == nil ? "nil" : "[]")"
                XCTAssertGreaterThan(try excursion(raw, in: canvasSize), tolerance, label)
                XCTAssertEqual(trimmed, backwards, label)

                let result = identify(trimmed, samples: samples, canvasSize: canvasSize, anchors: anchors)
                XCTAssertEqual(result.evidence.boundaryPassed, true, label)
                XCTAssertFalse(result.failedBoundary, label)
                XCTAssertEqual(result.evidence.shapePassed, false, label)
                XCTAssertFalse(result.accepted, label)
            }
        }
    }
}
