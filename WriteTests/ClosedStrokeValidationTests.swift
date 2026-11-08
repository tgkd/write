import XCTest
@testable import Write

final class ClosedStrokeValidationTests: XCTestCase {

    private let canvas = CGSize(width: 439, height: 439)
    private let centerUnits = CGPoint(x: 93.87, y: 15)
    private let radiusUnits: CGFloat = 7.12
    private let strict: ValidationConfig = {
        var config = ValidationConfig.standard
        config.leniency = GradingStrictness.strict.leniency
        return config
    }()

    private var references: [[CGPoint]] {
        let strokes = [
            KanjiStroke(
                strokeNumber: 1,
                pathData: "M20,25.12c1.25,0.88,3.75,2.25,6.5,1.38c2.75-0.87,7.31-2.38,11.38-4.5c6-3.12,8.42-1.01,4.25,4c-27.13,32.62-23.76,58.5-1.52,62.88c18.07,3.56,37.63-16.38,35.63-56.51c-0.72-14.5-0.17-14.78,4.12-1.75c3.76,11.38,10.26,20.76,16.14,26.5",
                strokeType: nil
            ),
            KanjiStroke(
                strokeNumber: 2,
                pathData: "M93.87,22.12c-9.62,0-9.25-14.25,0-14.25c9.75,0.01,9.5,14.25,0,14.25",
                strokeType: nil
            )
        ]
        return StrokeValidator.sampleReferenceStrokes(strokes, canvasSize: canvas, sampleCount: ValidationConfig.standard.sampleCount)
    }

    private func circle(
        startClock: CGFloat = 180,
        sweep: CGFloat = 360,
        clockwise: Bool = true,
        radiusScale: CGFloat = 1,
        aspect: CGFloat = 1,
        offset: CGVector = .zero
    ) -> [CGPoint] {
        let scale = canvas.width / StrokeRenderer.kanjiVGSize
        return (0..<96).map { index in
            let t = CGFloat(index) / 95
            let degrees = startClock + (clockwise ? 1 : -1) * sweep * t
            let radians = degrees * .pi / 180
            return CGPoint(
                x: (centerUnits.x + radiusUnits * radiusScale * aspect * sin(radians)) * scale + offset.dx,
                y: (centerUnits.y - radiusUnits * radiusScale / aspect * cos(radians)) * scale + offset.dy
            )
        }
    }

    private func accepted(_ points: [CGPoint], guideless: Bool = false, config: ValidationConfig? = nil) -> Bool {
        let result = StrokeValidator.identifyStroke(
            userPoints: points,
            referenceSamples: references,
            unmatchedIndices: [1],
            canvasSize: canvas,
            expectedStrokeIndex: 1,
            anchors: guideless ? [] : nil,
            config: config ?? strict
        )
        return result.accepted && result.correctOrder
    }

    func testCircleStartingAnywherePasses() {
        for start in stride(from: CGFloat(0), to: 360, by: 30) {
            XCTAssertTrue(accepted(circle(startClock: start)), "start \(start)")
        }
    }

    func testCircleInEitherDirectionPasses() {
        for start in [CGFloat(0), 90, 180, 270] {
            XCTAssertTrue(accepted(circle(startClock: start, clockwise: false)), "start \(start)")
        }
    }

    func testImperfectClosurePasses() {
        for sweep in [CGFloat(345), 375, 390] {
            XCTAssertTrue(accepted(circle(startClock: 40, sweep: sweep)), "sweep \(sweep)")
        }
    }

    func testOpenArcIsRejected() {
        for sweep in [CGFloat(180), 240, 270] {
            XCTAssertFalse(accepted(circle(sweep: sweep)), "sweep \(sweep)")
        }
    }

    func testExtraLapIsRejected() {
        for sweep in [CGFloat(480), 540, 720] {
            XCTAssertFalse(accepted(circle(sweep: sweep)), "sweep \(sweep)")
        }
    }

    func testDakutenTickInTheCirclesPlaceIsRejected() {
        let scale = canvas.width / StrokeRenderer.kanjiVGSize
        let tick = (0..<20).map { index -> CGPoint in
            let t = CGFloat(index) / 19
            return CGPoint(x: (88 + 10 * t) * scale, y: (10 + 10 * t) * scale)
        }
        XCTAssertFalse(accepted(tick))
    }

    func testMisplacedCircleIsRejected() {
        XCTAssertFalse(accepted(circle(offset: CGVector(dx: -60, dy: 60))))
    }

    func testStrictGuidelessStillChecksSize() {
        XCTAssertFalse(accepted(circle(radiusScale: 0.6), guideless: true))
        XCTAssertTrue(accepted(circle(radiusScale: 0.6), guideless: false))
    }

    func testStrictGivesTheCircleNormalsShapeLimit() {
        let oval = circle(aspect: 0.7)
        XCTAssertTrue(accepted(oval))
    }

    func testStrictKeepsItsShapeLimitOnOpenStrokes() {
        let strokes = [KanjiStroke(strokeNumber: 1, pathData: "M20,50 L90,50", strokeType: nil)]
        let reference = StrokeValidator.sampleReferenceStrokes(strokes, canvasSize: canvas, sampleCount: 50)
        let center = ProcrustesNormalizer.centroid(of: reference[0])
        let angle: CGFloat = 13 * .pi / 180
        let tilted = reference[0].map { point in
            CGPoint(
                x: center.x + (point.x - center.x) * cos(angle) - (point.y - center.y) * sin(angle),
                y: center.y + (point.x - center.x) * sin(angle) + (point.y - center.y) * cos(angle)
            )
        }
        func result(_ config: ValidationConfig) -> StrokeValidationResult {
            StrokeValidator.identifyStroke(
                userPoints: tilted,
                referenceSamples: reference,
                unmatchedIndices: [0],
                canvasSize: canvas,
                expectedStrokeIndex: 0,
                config: config
            )
        }
        XCTAssertTrue(result(.standard).accepted)
        XCTAssertFalse(result(strict).accepted)
    }

    func testStrictKeepsItsPlaceLimitOnTheCircle() {
        let moved = circle(offset: CGVector(dx: 17, dy: 0))
        XCTAssertFalse(accepted(moved))
        XCTAssertTrue(accepted(moved, config: .standard))
    }

    func testOpenReferenceStillCaresAboutDirection() {
        let samples = references[0]
        let result = StrokeValidator.identifyStroke(
            userPoints: samples.reversed(),
            referenceSamples: references,
            unmatchedIndices: [0],
            canvasSize: canvas,
            expectedStrokeIndex: 0,
            config: strict
        )
        XCTAssertFalse(result.accepted)
    }

    func testOnlyHandakutenCirclesAreClosed() throws {
        guard let url = Bundle.main.url(forResource: "kanji_strokes", withExtension: "json")
                ?? Bundle(for: type(of: self)).url(forResource: "kanji_strokes", withExtension: "json") else {
            throw XCTSkip("kanji_strokes.json not found in app or test bundle")
        }
        let store = try KanjiDataStore(data: Data(contentsOf: url))
        var closedCount = 0
        for codePoint in store.allCodePoints {
            guard let kanji = store.lookup(codePoint: codePoint), kanji.script != .kanji else {
                continue
            }
            let samples = StrokeValidator.sampleReferenceStrokes(
                kanji.strokes,
                canvasSize: CGSize(width: 109, height: 109),
                sampleCount: ValidationConfig.standard.sampleCount
            )
            for (index, stroke) in samples.enumerated() where ClosedStrokeMatcher.isClosed(stroke) {
                closedCount += 1
                XCTAssertLessThan(StrokeValidator.extent(of: stroke), 8, "\(kanji.text) stroke \(index + 1)")
            }
        }
        XCTAssertEqual(closedCount, 16)
    }
}
