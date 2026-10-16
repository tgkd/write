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

        XCTAssertEqual(small.maxHookLength, 5, accuracy: 0.0001)
        XCTAssertEqual(large.maxHookLength, 12, accuracy: 0.0001)
    }
}
