import XCTest
@testable import Write

final class GuidelessValidationTests: XCTestCase {

    private let canvasSize = CGSize(width: 300, height: 300)

    private let towerStrokes = [
        KanjiStroke(strokeNumber: 1, pathData: "M25,25 L85,25", strokeType: nil),
        KanjiStroke(strokeNumber: 2, pathData: "M55,25 L55,50", strokeType: nil),
        KanjiStroke(strokeNumber: 3, pathData: "M30,50 L80,50", strokeType: nil),
        KanjiStroke(strokeNumber: 4, pathData: "M55,50 L55,90", strokeType: nil),
        KanjiStroke(strokeNumber: 5, pathData: "M20,90 L90,90", strokeType: nil),
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

    func testOneStrokeCharacterIsJudgedWithoutProportion() {
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

    func testTinyFirstDotIsNotUsedForProportion() {
        let reference = samples(dotStrokes)
        let center = pivot(of: reference)
        let user = reference.map { drawn($0, scale: 0.95, about: center) }

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
    }

    func testCharacterDrawnAtTheReferenceSizeIsAccepted() {
        for strictness in GradingStrictness.allCases {
            let drawn = scaledSession(towerStrokes, scale: 1, config: config(strictness))
            XCTAssertEqual(drawn.results.count, towerStrokes.count, strictness.rawValue)
            XCTAssertTrue(drawn.results.allSatisfy { $0.accepted && $0.correctOrder }, strictness.rawValue)
        }
    }

    func testShrunkCharacterIsNotFollowedByTheReference() {
        let shrunk = scaledSession(towerStrokes, scale: 0.6, config: .standard)
        XCTAssertFalse(shrunk.results.allSatisfy { $0.accepted && $0.correctOrder })
        XCTAssertEqual(shrunk.results.last?.evidence.positionPassed, false)
    }

    func testShiftedCharacterIsNotFollowedByTheReference() {
        let reference = samples(towerStrokes)
        let user = reference.map { stroke in stroke.map { CGPoint(x: $0.x + 40, y: $0.y + 40) } }
        let shifted = session(user, samples: reference, config: .standard)
        XCTAssertFalse(shifted.results.allSatisfy { $0.accepted && $0.correctOrder })
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

    func testExpectedStrokeStillWinsOverALookalike() {
        let strokes = towerStrokes + [KanjiStroke(strokeNumber: 6, pathData: "M20,86 L90,86", strokeType: nil)]
        let reference = samples(strokes)
        let prior = session(Array(reference.prefix(4)), samples: reference, config: .standard)
        XCTAssertEqual(prior.anchors.count, 4)
        let lookalike = CGVector(dx: 0, dy: -4)
        let points = reference[4].map { CGPoint(x: $0.x + lookalike.dx, y: $0.y + lookalike.dy) }
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
        XCTAssertEqual(result.evidence, StrokeEvidence(boundaryPassed: true))
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
        XCTAssertFalse(config(.strict, base: ValidationConfig(enforcesProportion: false)).rejectsDisproportion)
    }
}
