import XCTest
@testable import Write

// MARK: - CatmullRomSpline Tests

final class CatmullRomSplineTests: XCTestCase {

    func testInterpolateWithSinglePoint() {
        let points = [CGPoint(x: 5, y: 5)]
        let result = CatmullRomSpline.interpolate(points: points)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], points[0])
    }

    func testInterpolateWithEmptyArray() {
        let result = CatmullRomSpline.interpolate(points: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testInterpolateWithTwoPoints() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)]
        let result = CatmullRomSpline.interpolate(points: points, subdivisions: 4)
        XCTAssertEqual(result.count, 5) // 4 subdivisions + 1
        XCTAssertEqual(result.first!, points.first!)
        XCTAssertEqual(result.last!, points.last!)
    }

    func testInterpolateThroughControlPoints() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 100),
            CGPoint(x: 100, y: 50),
            CGPoint(x: 150, y: 80)
        ]
        let result = CatmullRomSpline.interpolate(points: points, subdivisions: 8)

        // The smoothed curve must pass through all original control points
        for controlPoint in points {
            let found = result.contains { p in
                abs(p.x - controlPoint.x) < 0.001 && abs(p.y - controlPoint.y) < 0.001
            }
            XCTAssertTrue(found, "Result should pass through control point (\(controlPoint.x), \(controlPoint.y))")
        }
    }

    func testInterpolateFirstAndLastPointMatch() {
        let points = [
            CGPoint(x: 10, y: 20),
            CGPoint(x: 30, y: 60),
            CGPoint(x: 70, y: 40),
            CGPoint(x: 90, y: 80),
            CGPoint(x: 120, y: 30)
        ]
        let result = CatmullRomSpline.interpolate(points: points, subdivisions: 10)

        assertPointsEqual(result.first!, points.first!)
        assertPointsEqual(result.last!, points.last!)
    }

    func testInterpolateOutputCountWithThreePoints() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 0)
        ]
        let subdivisions = 8
        let result = CatmullRomSpline.interpolate(points: points, subdivisions: subdivisions)
        // 2 segments x (subdivisions + 1) points, minus 1 shared point = 2 * 9 - 1 = 17
        let expectedCount = (points.count - 1) * (subdivisions + 1) - (points.count - 2)
        XCTAssertEqual(result.count, expectedCount)
    }

    func testInterpolateProducesMorePointsThanInput() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 100),
            CGPoint(x: 100, y: 0)
        ]
        let result = CatmullRomSpline.interpolate(points: points, subdivisions: 4)
        XCTAssertGreaterThan(result.count, points.count)
    }

    func testCreatePathReturnsNonEmptyPath() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 0)
        ]
        let path = CatmullRomSpline.createPath(from: points)
        XCTAssertFalse(path.isEmpty)
    }

    func testCreatePathFromEmptyPoints() {
        let path = CatmullRomSpline.createPath(from: [])
        XCTAssertTrue(path.isEmpty)
    }

    func testCentripetalParameterization() {
        // Centripetal (alpha=0.5) should produce different results from uniform (alpha=0)
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 100),
            CGPoint(x: 100, y: 10),
            CGPoint(x: 110, y: 110)
        ]
        let centripetal = CatmullRomSpline.interpolate(points: points, alpha: 0.5, subdivisions: 4)
        let uniform = CatmullRomSpline.interpolate(points: points, alpha: 0.0, subdivisions: 4)

        // Both should pass through control points, but intermediate points differ
        var hasDifference = false
        for i in 0..<min(centripetal.count, uniform.count) {
            let dx = abs(centripetal[i].x - uniform[i].x)
            let dy = abs(centripetal[i].y - uniform[i].y)
            if dx > 0.1 || dy > 0.1 {
                hasDifference = true
                break
            }
        }
        XCTAssertTrue(hasDifference, "Centripetal and uniform parameterization should produce different curves")
    }

    // MARK: - Helpers

    private func assertPointsEqual(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 0.001, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: tolerance, file: file, line: line)
    }
}

// MARK: - DrawingCanvasView Tests

@MainActor
final class DrawingCanvasViewTests: XCTestCase {

    func testInitialState() {
        let canvas = DrawingCanvasView()
        XCTAssertEqual(canvas.strokeCount, 0)
        XCTAssertTrue(canvas.strokes.isEmpty)
        XCTAssertTrue(canvas.currentStrokePoints.isEmpty)
    }

    func testSimulateStrokeCapture() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        var pointAddedCount = 0
        var completedStrokes: [([CGPoint], Int)] = []

        canvas.onPointAdded = { _, _ in pointAddedCount += 1 }
        canvas.onStrokeCompleted = { points, index in completedStrokes.append((points, index)) }

        // Simulate touch sequence
        simulateStroke(on: canvas, points: [
            CGPoint(x: 10, y: 10),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 100)
        ])

        XCTAssertEqual(canvas.strokeCount, 1)
        XCTAssertEqual(canvas.strokes[0].count, 3)
        XCTAssertEqual(completedStrokes.count, 1)
        XCTAssertEqual(completedStrokes[0].1, 0) // stroke index 0
        // onPointAdded fires during touchesBegan and touchesMoved, not touchesEnded
        XCTAssertEqual(pointAddedCount, 2)
    }

    func testMultipleStrokesTracking() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        simulateStroke(on: canvas, points: [
            CGPoint(x: 10, y: 10),
            CGPoint(x: 50, y: 50)
        ])

        simulateStroke(on: canvas, points: [
            CGPoint(x: 100, y: 10),
            CGPoint(x: 150, y: 50)
        ])

        XCTAssertEqual(canvas.strokeCount, 2)
        XCTAssertEqual(canvas.strokes[0].first!, CGPoint(x: 10, y: 10))
        XCTAssertEqual(canvas.strokes[1].first!, CGPoint(x: 100, y: 10))
    }

    func testStrokeCompletedCallbackIndex() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        var indices: [Int] = []
        canvas.onStrokeCompleted = { _, index in indices.append(index) }

        simulateStroke(on: canvas, points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
        simulateStroke(on: canvas, points: [CGPoint(x: 20, y: 20), CGPoint(x: 30, y: 30)])
        simulateStroke(on: canvas, points: [CGPoint(x: 40, y: 40), CGPoint(x: 50, y: 50)])

        XCTAssertEqual(indices, [0, 1, 2])
    }

    func testRemoveLastStroke() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        simulateStroke(on: canvas, points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
        simulateStroke(on: canvas, points: [CGPoint(x: 20, y: 20), CGPoint(x: 30, y: 30)])

        XCTAssertEqual(canvas.strokeCount, 2)

        canvas.removeLastStroke()
        XCTAssertEqual(canvas.strokeCount, 1)
        XCTAssertEqual(canvas.strokes[0].first!, CGPoint(x: 0, y: 0))
    }

    func testClearAll() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        simulateStroke(on: canvas, points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
        simulateStroke(on: canvas, points: [CGPoint(x: 20, y: 20), CGPoint(x: 30, y: 30)])

        canvas.clearAll()
        XCTAssertEqual(canvas.strokeCount, 0)
        XCTAssertTrue(canvas.strokes.isEmpty)
    }

    func testRemoveOnEmptyCanvas() {
        let canvas = DrawingCanvasView()
        canvas.removeLastStroke() // should not crash
        canvas.clearAll() // should not crash
        XCTAssertEqual(canvas.strokeCount, 0)
    }

    func testStrokeLayerCountMatchesStrokeCount() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        simulateStroke(on: canvas, points: [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50)])
        simulateStroke(on: canvas, points: [CGPoint(x: 60, y: 60), CGPoint(x: 100, y: 100)])

        // sublayers should have 2 stroke layers
        let sublayerCount = canvas.layer.sublayers?.count ?? 0
        XCTAssertEqual(sublayerCount, 2)

        canvas.removeLastStroke()
        let afterRemove = canvas.layer.sublayers?.count ?? 0
        XCTAssertEqual(afterRemove, 1)

        canvas.clearAll()
        let afterClear = canvas.layer.sublayers?.count ?? 0
        XCTAssertEqual(afterClear, 0)
    }

    func testCurrentStrokePointsClearedAfterCompletion() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        simulateStroke(on: canvas, points: [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50)])

        XCTAssertTrue(canvas.currentStrokePoints.isEmpty, "currentStrokePoints should be empty after stroke completes")
    }

    // MARK: - Helpers

    private func simulateStroke(on canvas: DrawingCanvasView, points: [CGPoint]) {
        guard let first = points.first else { return }

        let beginTouch = TestTouch(locationInView: first)
        canvas.touchesBegan([beginTouch], with: nil)

        for point in points.dropFirst().dropLast() {
            let moveTouch = TestTouch(locationInView: point)
            canvas.touchesMoved([moveTouch], with: nil)
        }

        if points.count > 1 {
            let endTouch = TestTouch(locationInView: points.last!)
            canvas.touchesEnded([endTouch], with: nil)
        } else {
            canvas.touchesEnded([beginTouch], with: nil)
        }
    }
}

// MARK: - Test Touch Helper

private class TestTouch: UITouch {
    private let _locationInView: CGPoint

    init(locationInView: CGPoint) {
        _locationInView = locationInView
        super.init()
    }

    override func location(in view: UIView?) -> CGPoint {
        _locationInView
    }
}
