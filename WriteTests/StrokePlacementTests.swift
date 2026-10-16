import XCTest
@testable import Write

final class StrokePlacementTests: XCTestCase {

    private let canvasSize = CGSize(width: 300, height: 300)

    private let towerStrokes = [
        KanjiStroke(strokeNumber: 1, pathData: "M25,25 L85,25", strokeType: nil),
        KanjiStroke(strokeNumber: 2, pathData: "M55,25 L55,50", strokeType: nil),
        KanjiStroke(strokeNumber: 3, pathData: "M30,50 L80,50", strokeType: nil),
        KanjiStroke(strokeNumber: 4, pathData: "M55,50 L55,90", strokeType: nil),
        KanjiStroke(strokeNumber: 5, pathData: "M20,90 L90,90", strokeType: nil),
    ]

    private let crossStrokes = [
        KanjiStroke(strokeNumber: 1, pathData: "M20,55 L90,55", strokeType: nil),
        KanjiStroke(strokeNumber: 2, pathData: "M55,20 L55,90", strokeType: nil),
        KanjiStroke(strokeNumber: 3, pathData: "M30,95 L80,95", strokeType: nil),
    ]

    private let dotStrokes = [
        KanjiStroke(strokeNumber: 1, pathData: "M52,18 L56,24", strokeType: nil),
        KanjiStroke(strokeNumber: 2, pathData: "M20,35 L90,35", strokeType: nil),
        KanjiStroke(strokeNumber: 3, pathData: "M55,35 L55,90", strokeType: nil),
    ]

    private func samples(_ strokes: [KanjiStroke]) -> [[CGPoint]] {
        StrokeValidator.sampleReferenceStrokes(
            strokes, canvasSize: canvasSize, sampleCount: ValidationConfig.standard.sampleCount
        )
    }

    private func pivot(of samples: [[CGPoint]]) -> CGPoint {
        let points = samples.flatMap { $0 }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGPoint(x: (xs.min()! + xs.max()!) / 2, y: (ys.min()! + ys.max()!) / 2)
    }

    private func drawn(_ stroke: [CGPoint], scale: CGFloat, about pivot: CGPoint) -> [CGPoint] {
        stroke.map { CGPoint(x: pivot.x + scale * ($0.x - pivot.x), y: pivot.y + scale * ($0.y - pivot.y)) }
    }

    private func shrunk(_ stroke: [CGPoint], by factor: CGFloat) -> [CGPoint] {
        drawn(stroke, scale: factor, about: ProcrustesNormalizer.centroid(of: stroke))
    }

    private func config(_ strictness: GradingStrictness, base: ValidationConfig = .standard) -> ValidationConfig {
        var config = base
        config.leniency = strictness.leniency
        return config
    }

    private func identify(
        _ points: [CGPoint],
        samples: [[CGPoint]],
        index: Int,
        anchors: [StrokeAnchor]?,
        config: ValidationConfig = .standard
    ) -> StrokeValidationResult {
        StrokeValidator.identifyStroke(
            userPoints: points,
            referenceSamples: samples,
            unmatchedIndices: Set(index..<samples.count),
            canvasSize: canvasSize,
            expectedStrokeIndex: index,
            anchors: anchors,
            config: config
        )
    }

    private func session(
        _ user: [[CGPoint]],
        samples: [[CGPoint]],
        config: ValidationConfig
    ) -> (results: [StrokeValidationResult], anchors: [StrokeAnchor]) {
        var anchors: [StrokeAnchor] = []
        var results: [StrokeValidationResult] = []
        for index in user.indices {
            let result = identify(user[index], samples: samples, index: index, anchors: anchors, config: config)
            results.append(result)
            if result.accepted, result.correctOrder, let anchor = result.anchor {
                anchors.append(anchor)
            } else {
                return (results, anchors)
            }
        }
        return (results, anchors)
    }

    private func scaledSession(
        _ strokes: [KanjiStroke],
        scale: CGFloat,
        config: ValidationConfig
    ) -> (results: [StrokeValidationResult], anchors: [StrokeAnchor]) {
        let reference = samples(strokes)
        let center = pivot(of: reference)
        let user = reference.map { drawn($0, scale: scale, about: center) }
        return session(user, samples: reference, config: config)
    }

    func testNoAnchorsGiveTheIdentityPlacement() {
        let placement = StrokeValidator.placement(anchors: [], referenceSamples: samples(towerStrokes), canvasSize: canvasSize)
        XCTAssertEqual(placement, .identity)
    }

    func testPlacementAppliesScaleBeforeOffset() {
        let placement = StrokePlacement(scale: 0.5, offset: CGVector(dx: 10, dy: -4))
        let point = placement.apply(to: CGPoint(x: 100, y: 40))
        XCTAssertEqual(point.x, 60, accuracy: 0.0001)
        XCTAssertEqual(point.y, 16, accuracy: 0.0001)
    }

    func testOneStrokeCharacterIsJudgedWithoutAFittedScale() {
        let reference = samples([towerStrokes[4]])
        let user = drawn(reference[0], scale: 0.7, about: pivot(of: reference))
        let result = identify(user, samples: reference, index: 0, anchors: [])
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.evidence.shapePassed, true)
        XCTAssertEqual(result.evidence.positionPassed, true)
        XCTAssertNil(result.evidence.proportionPassed)
        XCTAssertEqual(result.anchor?.referenceIndex, 0)
        XCTAssertGreaterThan(result.anchor?.userExtent ?? 0, 0)
    }

    func testOneAnchorKeepsTheScaleAtOne() {
        let reference = samples(towerStrokes)
        let user = drawn(reference[0], scale: 0.7, about: pivot(of: reference))
        let anchor = identify(user, samples: reference, index: 0, anchors: []).anchor!
        let placement = StrokeValidator.placement(anchors: [anchor], referenceSamples: reference, canvasSize: canvasSize)
        let referenceCentroid = ProcrustesNormalizer.centroid(of: reference[0])
        XCTAssertEqual(placement.scale, 1)
        XCTAssertEqual(placement.offset.dx, anchor.userCentroid.x - referenceCentroid.x, accuracy: 0.001)
        XCTAssertEqual(placement.offset.dy, anchor.userCentroid.y - referenceCentroid.y, accuracy: 0.001)
    }

    func testAnchorsWithNearbyCentroidsKeepTheScaleAtOne() {
        let reference = samples(crossStrokes)
        let center = pivot(of: reference)
        let anchors = (0..<2).map { index in
            identify(drawn(reference[index], scale: 0.7, about: center), samples: reference, index: index, anchors: []).anchor!
        }
        let placement = StrokeValidator.placement(anchors: anchors, referenceSamples: reference, canvasSize: canvasSize)
        XCTAssertEqual(placement.scale, 1)
    }

    func testTinyFirstDotIsNotUsedForProportionOrScale() {
        let reference = samples(dotStrokes)
        let center = pivot(of: reference)
        let user = reference.map { drawn($0, scale: 0.8, about: center) }

        let dot = identify(user[0], samples: reference, index: 0, anchors: [])
        XCTAssertTrue(dot.accepted)
        XCTAssertNil(dot.evidence.proportionPassed)

        let anchors = [dot.anchor!]
        XCTAssertNil(StrokeValidator.proportionScale(
            anchors: anchors, referenceSamples: reference, canvasSize: canvasSize, config: .standard
        ))
        let second = identify(user[1], samples: reference, index: 1, anchors: anchors)
        XCTAssertTrue(second.accepted)
        XCTAssertNil(second.evidence.proportionPassed)

        let placement = StrokeValidator.placement(
            anchors: anchors + [second.anchor!], referenceSamples: reference, canvasSize: canvasSize
        )
        XCTAssertLessThanOrEqual(placement.scale, 1)
        XCTAssertGreaterThan(placement.scale, 0.9)
    }

    func testConsistentlySmallCharacterIsAccepted() {
        let fitted = scaledSession(towerStrokes, scale: 0.7, config: .standard)
        XCTAssertEqual(fitted.results.count, towerStrokes.count)
        XCTAssertTrue(fitted.results.allSatisfy { $0.accepted && $0.correctOrder })
        XCTAssertTrue(fitted.results.allSatisfy { $0.evidence.proportionPassed != false })

        let baseline = scaledSession(towerStrokes, scale: 0.7, config: .translationOnly)
        XCTAssertFalse(baseline.results.allSatisfy { $0.accepted && $0.correctOrder })

        let placement = StrokeValidator.placement(
            anchors: Array(fitted.anchors.prefix(4)), referenceSamples: samples(towerStrokes), canvasSize: canvasSize
        )
        XCTAssertEqual(placement.scale, 0.7, accuracy: 0.02)
    }

    func testConsistentlySmallCharacterIsAcceptedAtStrict() {
        let fitted = scaledSession(towerStrokes, scale: 0.7, config: config(.strict))
        XCTAssertEqual(fitted.results.count, towerStrokes.count)
        XCTAssertTrue(fitted.results.allSatisfy { $0.accepted && $0.correctOrder })
    }

    func testConsistentlyLargeCharacterIsAccepted() {
        for strictness in [GradingStrictness.normal, .strict] {
            let fitted = scaledSession(towerStrokes, scale: 1.25, config: config(strictness))
            XCTAssertEqual(fitted.results.count, towerStrokes.count, strictness.rawValue)
            XCTAssertTrue(fitted.results.allSatisfy { $0.accepted && $0.correctOrder }, strictness.rawValue)
            XCTAssertTrue(fitted.results.allSatisfy { $0.evidence.proportionPassed != false }, strictness.rawValue)
        }
        let placement = StrokeValidator.placement(
            anchors: Array(scaledSession(towerStrokes, scale: 1.25, config: .standard).anchors.prefix(4)),
            referenceSamples: samples(towerStrokes),
            canvasSize: canvasSize
        )
        XCTAssertEqual(placement.scale, 1.25, accuracy: 0.03)
    }

    func testAnomalouslyShortStrokeIsOnlyRejectedAtStrict() {
        let reference = samples(towerStrokes)
        let prior = session(Array(reference.prefix(3)), samples: reference, config: .standard)
        XCTAssertEqual(prior.anchors.count, 3)
        let short = shrunk(reference[3], by: 0.5)

        let normal = identify(short, samples: reference, index: 3, anchors: prior.anchors, config: config(.normal))
        XCTAssertTrue(normal.accepted)
        XCTAssertEqual(normal.matchedStrokeIndex, 3)
        XCTAssertEqual(normal.evidence.proportionPassed, false)

        let lenient = identify(short, samples: reference, index: 3, anchors: prior.anchors, config: config(.lenient))
        XCTAssertTrue(lenient.accepted)

        let strict = identify(short, samples: reference, index: 3, anchors: prior.anchors, config: config(.strict))
        XCTAssertFalse(strict.accepted)
        XCTAssertEqual(strict.matchedStrokeIndex, 3)
        XCTAssertEqual(strict.evidence.shapePassed, true)
        XCTAssertEqual(strict.evidence.positionPassed, true)
        XCTAssertEqual(strict.evidence.proportionPassed, false)
    }

    func testProportionNeverRejectsWhenTheGuideIsShown() {
        let reference = samples(towerStrokes)
        let short = shrunk(reference[3], by: 0.5)
        let result = identify(short, samples: reference, index: 3, anchors: nil, config: config(.strict))
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.evidence.proportionPassed, false)

        let exact = identify(reference[3], samples: reference, index: 3, anchors: nil, config: config(.strict))
        XCTAssertEqual(exact.evidence.proportionPassed, true)
    }

    func testTraceAcceptanceIgnoresTheScaleFit() {
        let reference = samples(towerStrokes)
        let user = drawn(reference[4], scale: 0.9, about: pivot(of: reference))
        let fitted = identify(user, samples: reference, index: 4, anchors: nil, config: .standard)
        let baseline = identify(user, samples: reference, index: 4, anchors: nil, config: .translationOnly)
        XCTAssertEqual(fitted.accepted, baseline.accepted)
        XCTAssertEqual(fitted.score, baseline.score, accuracy: 0.0001)
        XCTAssertEqual(fitted.frechetDistance, baseline.frechetDistance, accuracy: 0.0001)
    }

    func testUndoRestoresThePlacementOfTheRemainingAnchors() {
        let fitted = scaledSession(towerStrokes, scale: 0.7, config: .standard)
        let reference = samples(towerStrokes)
        let prefix = Array(fitted.anchors.prefix(3))
        var undone = Array(fitted.anchors.prefix(4))
        undone.removeAll { $0.referenceIndex == 3 }
        XCTAssertEqual(
            StrokeValidator.placement(anchors: undone, referenceSamples: reference, canvasSize: canvasSize),
            StrokeValidator.placement(anchors: prefix, referenceSamples: reference, canvasSize: canvasSize)
        )
    }

    func testFittedScaleIsBoundedAndKeepsTheReferenceOnTheCanvas() {
        let reference = samples(towerStrokes)
        let center = pivot(of: reference)
        let anchors = (0..<4).map { index -> StrokeAnchor in
            let user = drawn(reference[index], scale: 3, about: center)
            return StrokeAnchor(referenceIndex: index, userCentroid: ProcrustesNormalizer.centroid(of: user))
        }
        let config = ValidationConfig.standard
        let placement = StrokeValidator.placement(
            anchors: anchors, referenceSamples: reference, canvasSize: canvasSize, config: config
        )
        XCTAssertLessThanOrEqual(placement.scale, config.maximumScale)
        XCTAssertGreaterThan(placement.scale, 1)
        for point in reference.flatMap({ $0 }).map(placement.apply(to:)) {
            XCTAssertGreaterThanOrEqual(point.x, -0.001)
            XCTAssertGreaterThanOrEqual(point.y, -0.001)
            XCTAssertLessThanOrEqual(point.x, canvasSize.width + 0.001)
            XCTAssertLessThanOrEqual(point.y, canvasSize.height + 0.001)
        }
    }

    func testTranslationOnlyConfigMatchesThePlacementOffset() {
        let fitted = scaledSession(towerStrokes, scale: 0.7, config: .standard)
        let reference = samples(towerStrokes)
        let placement = StrokeValidator.placement(
            anchors: fitted.anchors, referenceSamples: reference, canvasSize: canvasSize, config: .translationOnly
        )
        let offset = StrokeValidator.placementOffset(anchors: fitted.anchors, referenceSamples: reference, canvasSize: canvasSize)
        XCTAssertEqual(placement.scale, 1)
        XCTAssertEqual(placement.offset.dx, offset.dx, accuracy: 0.0001)
        XCTAssertEqual(placement.offset.dy, offset.dy, accuracy: 0.0001)
    }

    func testExpectedStrokeStillWinsOverALookalikeWithAFittedScale() {
        let strokes = towerStrokes + [KanjiStroke(strokeNumber: 6, pathData: "M20,86 L90,86", strokeType: nil)]
        let reference = samples(strokes)
        let center = pivot(of: reference)
        let user = reference.map { drawn($0, scale: 0.7, about: center) }
        let prior = session(Array(user.prefix(4)), samples: reference, config: .standard)
        XCTAssertEqual(prior.anchors.count, 4)
        let lookalike = CGVector(dx: 0, dy: -4)
        let points = user[4].map { CGPoint(x: $0.x + lookalike.dx, y: $0.y + lookalike.dy) }
        let result = StrokeValidator.identifyStroke(
            userPoints: points,
            referenceSamples: reference,
            unmatchedIndices: [4, 5],
            canvasSize: canvasSize,
            expectedStrokeIndex: 4,
            anchors: prior.anchors
        )
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.matchedStrokeIndex, 4)
        XCTAssertTrue(result.correctOrder)
    }

    func testEvidenceIsNotEvaluatedWhenNoCandidateIsCompared() {
        let result = identify(
            [CGPoint(x: 290, y: 290), CGPoint(x: 295, y: 295)],
            samples: samples([KanjiStroke(strokeNumber: 1, pathData: "M10,10 L10,30", strokeType: nil)]),
            index: 0,
            anchors: []
        )
        XCTAssertNil(result.matchedStrokeIndex)
        XCTAssertEqual(result.evidence, .notEvaluated)
        XCTAssertNil(result.anchor)
    }

    func testEvidenceRecordsAFailedShape() {
        let reference = samples(towerStrokes)
        let result = identify(Array(reference[0].reversed()), samples: reference, index: 0, anchors: nil)
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.evidence.shapePassed, false)
        XCTAssertNotNil(result.evidence.positionPassed)
    }

    func testOnlyStrictLeniencyRejectsDisproportion() {
        XCTAssertTrue(config(.strict).rejectsDisproportion)
        XCTAssertFalse(config(.normal).rejectsDisproportion)
        XCTAssertFalse(config(.lenient).rejectsDisproportion)
        XCTAssertFalse(config(.strict, base: .translationOnly).rejectsDisproportion)
    }
}
