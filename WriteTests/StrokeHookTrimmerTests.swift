import XCTest
import CoreGraphics
@testable import Write

final class StrokeHookTrimmerTests: XCTestCase {

    private func segment(from a: CGPoint, to b: CGPoint, spacing: CGFloat = 1) -> [CGPoint] {
        let length = hypot(b.x - a.x, b.y - a.y)
        let steps = max(1, Int((length / spacing).rounded()))
        return (1...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    private func polyline(_ corners: [CGPoint], spacing: CGFloat = 1) -> [CGPoint] {
        guard let first = corners.first else {
            return []
        }
        var result = [first]
        for (a, b) in zip(corners, corners.dropFirst()) {
            result.append(contentsOf: segment(from: a, to: b, spacing: spacing))
        }
        return result
    }

    private func hooked() -> [CGPoint] {
        polyline([
            CGPoint(x: 22.12, y: 102.12),
            CGPoint(x: 20, y: 100),
            CGPoint(x: 120, y: 100),
            CGPoint(x: 117.17, y: 102.83)
        ])
    }

    func testStartAndEndHooksOnStraightLineAreTrimmed() {
        let trimmed = StrokeHookTrimmer.trim(hooked())

        guard let first = trimmed.first, let last = trimmed.last else {
            return XCTFail("Trimming must keep the line")
        }
        XCTAssertEqual(first.x, 20, accuracy: 0.01)
        XCTAssertEqual(first.y, 100, accuracy: 0.01)
        XCTAssertEqual(last.x, 120, accuracy: 0.01)
        XCTAssertEqual(last.y, 100, accuracy: 0.01)
        XCTAssertTrue(trimmed.allSatisfy { abs($0.y - 100) < 0.01 })
    }

    func testTrimmedRangeSlicesTheOriginalPoints() {
        let points = hooked()
        let range = StrokeHookTrimmer.keptRange(of: points)

        XCTAssertGreaterThan(range.lowerBound, 0)
        XCTAssertLessThan(range.upperBound, points.count)
        XCTAssertEqual(Array(points[range]), StrokeHookTrimmer.trim(points))
    }

    func testTrimmingIsIdempotent() {
        let once = StrokeHookTrimmer.trim(hooked())
        XCTAssertEqual(StrokeHookTrimmer.trim(once), once)

        let noisy = hooked().enumerated().map { i, p in
            CGPoint(x: p.x, y: p.y + (i.isMultiple(of: 2) ? 0.3 : -0.3))
        }
        let noisyOnce = StrokeHookTrimmer.trim(noisy)
        XCTAssertEqual(StrokeHookTrimmer.trim(noisyOnce), noisyOnce)
    }

    func testDotIsUntouched() {
        let dot = polyline([
            CGPoint(x: 50, y: 50),
            CGPoint(x: 52, y: 51),
            CGPoint(x: 51, y: 53),
            CGPoint(x: 49, y: 51),
            CGPoint(x: 51, y: 49)
        ], spacing: 0.5)

        XCTAssertEqual(StrokeHookTrimmer.trim(dot), dot)
    }

    func testShortTickWithTurnIsUntouched() {
        let tick = polyline([
            CGPoint(x: 50, y: 50),
            CGPoint(x: 62, y: 50),
            CGPoint(x: 59, y: 53)
        ])

        XCTAssertEqual(StrokeHookTrimmer.trim(tick), tick)
    }

    func testLongHookAtEndOfVerticalIsKept() {
        let vertical = polyline([
            CGPoint(x: 100, y: 20),
            CGPoint(x: 100, y: 220),
            CGPoint(x: 75, y: 195)
        ])

        XCTAssertEqual(StrokeHookTrimmer.trim(vertical), vertical)
    }

    func testMediumHookJustOutsideTheWindowIsKept() {
        let vertical = polyline([
            CGPoint(x: 100, y: 20),
            CGPoint(x: 100, y: 120),
            CGPoint(x: 93, y: 113)
        ])

        XCTAssertEqual(StrokeHookTrimmer.trim(vertical), vertical)
    }

    func testSweepIsKept() {
        var sweep = polyline([CGPoint(x: 20, y: 20), CGPoint(x: 150, y: 150)])
        for i in 1...50 {
            let t = CGFloat(i) / 50
            let angle = (.pi / 4) * (1 - t)
            let last = sweep[sweep.count - 1]
            sweep.append(CGPoint(x: last.x + cos(angle), y: last.y + sin(angle)))
        }

        XCTAssertEqual(StrokeHookTrimmer.trim(sweep), sweep)
    }

    func testStraightLineIsUntouched() {
        let line = polyline([CGPoint(x: 10, y: 10), CGPoint(x: 110, y: 60)])

        XCTAssertEqual(StrokeHookTrimmer.trim(line), line)
    }

    func testCanvasParametersAreBounded() {
        let small = StrokeHookTrimmer.Parameters(canvasSize: CGSize(width: 80, height: 80))
        let large = StrokeHookTrimmer.Parameters(canvasSize: CGSize(width: 2000, height: 2000))

        XCTAssertEqual(small.maxHookLength, 10, accuracy: 0.0001)
        XCTAssertEqual(large.maxHookLength, 12, accuracy: 0.0001)
    }

    private let cell = CGSize(width: 200, height: 200)

    private func hookedInCell() -> [CGPoint] {
        polyline([
            CGPoint(x: 46, y: 106),
            CGPoint(x: 40, y: 100),
            CGPoint(x: 90, y: 100),
            CGPoint(x: 84, y: 106)
        ])
    }

    func testPenSizedHooksAreTrimmedInASmallCell() {
        let trimmed = StrokeHookTrimmer.trim(hookedInCell(), parameters: .init(canvasSize: cell))

        XCTAssertTrue(trimmed.allSatisfy { abs($0.y - 100) < 0.01 })
        XCTAssertEqual(trimmed.first?.x ?? 0, 40, accuracy: 0.01)
        XCTAssertEqual(trimmed.last?.x ?? 0, 90, accuracy: 0.01)
    }

    func testLegacyParametersKeepPenSizedHooksInASmallCell() {
        let points = hookedInCell()

        XCTAssertEqual(StrokeHookTrimmer.trim(points, parameters: .legacy(canvasSize: cell)), points)
    }

    func testHookLongerThanTheWindowIsKeptInASmallCell() {
        let points = polyline([
            CGPoint(x: 40, y: 100),
            CGPoint(x: 90, y: 100),
            CGPoint(x: 80, y: 110)
        ])

        XCTAssertEqual(StrokeHookTrimmer.trim(points, parameters: .init(canvasSize: cell)), points)
    }

    func testSmallCircleIsNotTrimmed() {
        let circle = (0...90).map { step -> CGPoint in
            let angle = CGFloat(step) / 90 * 2 * .pi
            return CGPoint(x: 100 + 13 * sin(angle), y: 100 + 13 * cos(angle))
        }

        XCTAssertEqual(StrokeHookTrimmer.trim(circle, parameters: .init(canvasSize: cell)), circle)
        XCTAssertLessThan(StrokeHookTrimmer.trim(circle, parameters: .legacy(canvasSize: cell)).count, circle.count)
    }

    private func pressed(_ points: [CGPoint], faintStart: Int, faintEnd: Int) -> [CGFloat] {
        points.indices.map { index in
            index < faintStart || index >= points.count - faintEnd ? 0.03 : 0.3
        }
    }

    func testFaintTailsAreDropped() {
        let line = polyline([CGPoint(x: 40, y: 100), CGPoint(x: 100, y: 100)])
        let forces = pressed(line, faintStart: 5, faintEnd: 7)

        let range = StrokeHookTrimmer.keptRange(of: line, forces: forces, parameters: .init(canvasSize: cell))

        XCTAssertEqual(range, 5..<(line.count - 7))
    }

    func testFaintTailCutStaysInsideTheHookWindow() {
        let line = polyline([CGPoint(x: 40, y: 100), CGPoint(x: 100, y: 100)])
        let forces = pressed(line, faintStart: 30, faintEnd: 0)

        let range = StrokeHookTrimmer.keptRange(of: line, forces: forces, parameters: .init(canvasSize: cell))

        XCTAssertEqual(range, 10..<line.count)
    }

    func testEvenPressureAndMissingForceLeaveTheLineAlone() {
        let line = polyline([CGPoint(x: 40, y: 100), CGPoint(x: 100, y: 100)])
        let even = [CGFloat](repeating: 0.3, count: line.count)

        XCTAssertEqual(StrokeHookTrimmer.trim(line, forces: even, parameters: .init(canvasSize: cell)), line)
        XCTAssertEqual(StrokeHookTrimmer.trim(line, forces: [], parameters: .init(canvasSize: cell)), line)
        XCTAssertEqual(StrokeHookTrimmer.trim(line, forces: [0.3, 0.3], parameters: .init(canvasSize: cell)), line)
    }

    func testCapturedPencilStrokeWithFaintHooksPassesOnlyOnceTrimmed() {
        let filtered: [CGPoint] = [
            (40.7, 54.7), (40.7, 54.7), (40.9, 54.9), (41.2, 55.3), (41.5, 55.6), (41.9, 56.0), (42.0, 56.2),
            (42.1, 56.4), (42.2, 56.4), (42.2, 56.5), (42.2, 56.5), (42.2, 56.6), (42.2, 56.6), (42.2, 56.6),
            (42.2, 56.6), (42.2, 56.6), (42.2, 56.6), (42.2, 56.6), (42.2, 56.7), (42.2, 56.7), (42.2, 56.9),
            (42.1, 57.2), (42.0, 57.7), (42.0, 58.4), (41.9, 59.3), (41.8, 60.5), (41.6, 62.0), (41.3, 63.9),
            (41.0, 66.2), (40.6, 69.2), (40.1, 72.3), (39.4, 75.8), (38.6, 79.7), (37.5, 84.0), (36.3, 88.5),
            (34.8, 93.6), (33.2, 97.9), (31.7, 102.1), (30.1, 106.2), (28.5, 109.9), (26.9, 113.3), (25.4, 116.8),
            (24.3, 119.0), (23.3, 120.8), (22.6, 122.3), (21.9, 123.6), (21.3, 124.6), (20.7, 125.6), (20.3, 126.3),
            (19.9, 126.8), (19.6, 127.3), (19.3, 127.6), (19.1, 127.8), (19.1, 127.9), (19.0, 127.9), (19.0, 127.9),
            (19.0, 127.9), (19.0, 127.8), (19.0, 127.6), (19.1, 127.3), (19.4, 126.4), (19.9, 125.3), (20.4, 124.2),
            (21.0, 123.1), (21.5, 122.1), (22.1, 120.9), (22.6, 120.0), (24.2, 118.4)
        ].map { CGPoint(x: $0.0, y: $0.1) }
        let forces: [CGFloat] = [
            0.20, 0.20, 0.21, 0.26, 0.29, 0.32, 0.34, 0.36, 0.38, 0.39, 0.39, 0.39, 0.39, 0.39, 0.39, 0.40, 0.40,
            0.41, 0.41, 0.42, 0.42, 0.42, 0.44, 0.45, 0.46, 0.47, 0.49, 0.50, 0.52, 0.53, 0.54, 0.54, 0.55, 0.55,
            0.55, 0.56, 0.56, 0.56, 0.56, 0.55, 0.55, 0.55, 0.54, 0.54, 0.53, 0.53, 0.52, 0.50, 0.48, 0.46, 0.44,
            0.41, 0.37, 0.33, 0.29, 0.25, 0.23, 0.21, 0.18, 0.14, 0.11, 0.08, 0.05, 0.02, 0.01, 0.00, 0.00, 0.00
        ]
        let stroke = KanjiStroke(
            strokeNumber: 2,
            pathData: "M23.28,30.9c0.47,0.98,0.58,2.06,0.42,3.34C22.8,41.8,17.38,57.88,10,69.81",
            strokeType: nil
        )
        var config = ValidationConfig.standard
        config.leniency = GradingStrictness.strict.leniency
        let reference = StrokeValidator.sampleReferenceStrokes([stroke], canvasSize: cell, sampleCount: config.sampleCount)

        func accepted(_ points: [CGPoint]) -> Bool {
            StrokeValidator.identifyStroke(
                userPoints: points,
                referenceSamples: reference,
                unmatchedIndices: [0],
                canvasSize: cell,
                expectedStrokeIndex: 0,
                config: config
            ).accepted
        }

        XCTAssertFalse(accepted(StrokeHookTrimmer.trim(filtered, parameters: .legacy(canvasSize: cell))))
        XCTAssertTrue(accepted(StrokeHookTrimmer.trim(filtered, forces: forces, parameters: .init(canvasSize: cell))))
    }
}
