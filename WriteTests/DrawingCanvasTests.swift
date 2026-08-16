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

    // MARK: - Pencil takeover

    func testPencilTakesOverActiveFingerStroke() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        let finger = TestTouch(locationInView: CGPoint(x: 10, y: 10))
        canvas.touchesBegan([finger], with: nil)
        finger.updateLocation(CGPoint(x: 40, y: 40))
        canvas.touchesMoved([finger], with: nil)

        let pencil = TestTouch(locationInView: CGPoint(x: 200, y: 200))
        pencil.touchType = .pencil
        canvas.touchesBegan([pencil], with: nil)

        XCTAssertEqual(canvas.currentStrokePoints.first, CGPoint(x: 200, y: 200),
            "Pencil must take over: the active stroke restarts at the pencil location")

        pencil.updateLocation(CGPoint(x: 250, y: 250))
        canvas.touchesEnded([pencil], with: nil)

        XCTAssertEqual(canvas.strokeCount, 1, "The finger stroke must be discarded, not committed")
        XCTAssertEqual(canvas.strokes[0].first, CGPoint(x: 200, y: 200))
        XCTAssertEqual(canvas.layer.sublayers?.count ?? 0, 1,
            "The abandoned finger stroke must leave no layer behind")
    }

    func testFingerCannotInterruptPencilStroke() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        let pencil = TestTouch(locationInView: CGPoint(x: 100, y: 100))
        pencil.touchType = .pencil
        canvas.touchesBegan([pencil], with: nil)

        let finger = TestTouch(locationInView: CGPoint(x: 20, y: 20))
        canvas.touchesBegan([finger], with: nil)

        XCTAssertEqual(canvas.currentStrokePoints.first, CGPoint(x: 100, y: 100),
            "A finger touch must not interrupt an active pencil stroke")

        canvas.touchesEnded([pencil], with: nil)
        XCTAssertEqual(canvas.strokeCount, 1)
    }

    func testSimultaneousPencilAndFingerSelectsPencil() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        let finger = TestTouch(locationInView: CGPoint(x: 20, y: 20))
        let pencil = TestTouch(locationInView: CGPoint(x: 100, y: 100))
        pencil.touchType = .pencil

        canvas.touchesBegan([finger, pencil], with: nil)

        XCTAssertEqual(canvas.currentStrokePoints.first, CGPoint(x: 100, y: 100),
            "A pencil arriving in the same event as a finger must always win")
    }

    // MARK: - Clear during an active stroke

    func testClearAllDuringActiveStrokeLeavesNoPhantomStroke() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        let touch = TestTouch(locationInView: CGPoint(x: 10, y: 10))
        canvas.touchesBegan([touch], with: nil)
        touch.updateLocation(CGPoint(x: 60, y: 60))
        canvas.touchesMoved([touch], with: nil)

        canvas.clearAll()

        touch.updateLocation(CGPoint(x: 90, y: 90))
        canvas.touchesEnded([touch], with: nil)

        XCTAssertEqual(canvas.strokeCount, 0,
            "A touch that ends after clearAll must not commit a phantom stroke")
        XCTAssertEqual(canvas.layer.sublayers?.count ?? 0, 0,
            "clearAll must leave no ink layers behind")
    }

    func testRemoveLastStrokeIsSafeAfterClearDuringActiveStroke() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        let touch = TestTouch(locationInView: CGPoint(x: 10, y: 10))
        canvas.touchesBegan([touch], with: nil)
        touch.updateLocation(CGPoint(x: 60, y: 60))
        canvas.touchesMoved([touch], with: nil)

        canvas.clearAll()
        canvas.touchesEnded([touch], with: nil)

        canvas.removeLastStroke()

        XCTAssertEqual(canvas.strokeCount, 0)
    }

    func testStrokeAfterClearDuringActiveStrokeCommitsNormally() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        let interrupted = TestTouch(locationInView: CGPoint(x: 10, y: 10))
        canvas.touchesBegan([interrupted], with: nil)
        canvas.clearAll()
        canvas.touchesEnded([interrupted], with: nil)

        simulateStroke(on: canvas, points: [CGPoint(x: 100, y: 100), CGPoint(x: 150, y: 150)])

        XCTAssertEqual(canvas.strokeCount, 1)
        XCTAssertEqual(canvas.strokes[0].first, CGPoint(x: 100, y: 100))
        XCTAssertEqual(canvas.layer.sublayers?.count ?? 0, 1)
    }

    // MARK: - Estimated property refinement

    /// Draws a pencil stroke whose force values are estimates, then delivers
    /// refined (higher) force after the stroke was finalized. The committed
    /// layer's ribbon must widen.
    func testEstimatedForceRefinementUpdatesFinalizedStroke() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        canvas.brushConfig.pressureSensitivity = .high

        let touch = TestTouch(locationInView: CGPoint(x: 20, y: 100))
        touch.touchType = .pencil
        touch.testForce = 0.1
        touch.expectingUpdates = [.force]
        touch.estimationIndex = NSNumber(value: 1)
        canvas.touchesBegan([touch], with: nil)

        for (i, x) in [60, 100, 140, 180].enumerated() {
            touch.updateLocation(CGPoint(x: CGFloat(x), y: 100))
            touch.estimationIndex = NSNumber(value: i + 2)
            canvas.touchesMoved([touch], with: nil)
        }
        touch.updateLocation(CGPoint(x: 220, y: 100))
        touch.estimationIndex = NSNumber(value: 6)
        canvas.touchesEnded([touch], with: nil)

        guard let strokeLayer = canvas.layer.sublayers?.first as? CAShapeLayer,
              let pathBefore = strokeLayer.path else {
            return XCTFail("Expected a committed stroke layer with a path")
        }
        let heightBefore = pathBefore.boundingBoxOfPath.height

        // Deliver refinements for every recorded sample with much higher force.
        touch.testForce = 3.9
        for key in 1...6 {
            touch.estimationIndex = NSNumber(value: key)
            canvas.touchesEstimatedPropertiesUpdated([touch])
        }

        guard let pathAfter = strokeLayer.path else {
            return XCTFail("Layer path missing after refinement")
        }
        XCTAssertGreaterThan(pathAfter.boundingBoxOfPath.height, heightBefore + 0.5,
            "Refined higher force must widen the committed ribbon")
    }

    func testEstimatedForceRefinementUpdatesActiveStroke() {
        let canvas = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        canvas.brushConfig.pressureSensitivity = .high

        let touch = TestTouch(locationInView: CGPoint(x: 20, y: 100))
        touch.touchType = .pencil
        touch.testForce = 0.1
        touch.expectingUpdates = [.force]
        touch.estimationIndex = NSNumber(value: 10)
        canvas.touchesBegan([touch], with: nil)

        touch.updateLocation(CGPoint(x: 120, y: 100))
        touch.estimationIndex = NSNumber(value: 11)
        canvas.touchesMoved([touch], with: nil)

        guard let activeLayer = canvas.layer.sublayers?.first as? CAShapeLayer,
              let before = activeLayer.path else {
            return XCTFail("Expected an active stroke layer")
        }
        let heightBefore = before.boundingBoxOfPath.height

        touch.testForce = 3.9
        for key in [10, 11] {
            touch.estimationIndex = NSNumber(value: key)
            canvas.touchesEstimatedPropertiesUpdated([touch])
        }

        guard let after = activeLayer.path else { return XCTFail("Active path missing") }
        XCTAssertGreaterThan(after.boundingBoxOfPath.height, heightBefore + 0.5,
            "Refined force must re-render the in-progress stroke")

        canvas.touchesEnded([touch], with: nil)
    }

    // MARK: - Helpers

    private func simulateStroke(on canvas: DrawingCanvasView, points: [CGPoint]) {
        guard let first = points.first else { return }

        let touch = TestTouch(locationInView: first)
        canvas.touchesBegan([touch], with: nil)

        for point in points.dropFirst().dropLast() {
            touch.updateLocation(point)
            canvas.touchesMoved([touch], with: nil)
        }

        if points.count > 1 {
            touch.updateLocation(points.last!)
            canvas.touchesEnded([touch], with: nil)
        } else {
            canvas.touchesEnded([touch], with: nil)
        }
    }
}

// MARK: - NotebookCellView Tests

@MainActor
final class NotebookCellViewTests: XCTestCase {

    func testInkSurvivesInPlaceSettingsUpdate() {
        let cell = NotebookCellView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        cell.configurePractice(
            showCrosshair: true,
            allowedTouchTypes: [.direct, .pencil],
            pressureSensitivity: .off,
            tiltSensitivity: .off,
            smoothingStrength: .medium,
            brushThickness: .medium
        )

        guard let canvas = cell.canvasView else {
            return XCTFail("Practice cell should have a canvas")
        }

        let touch = TestTouch(locationInView: CGPoint(x: 10, y: 10))
        canvas.touchesBegan([touch], with: nil)
        touch.updateLocation(CGPoint(x: 60, y: 60))
        canvas.touchesEnded([touch], with: nil)
        XCTAssertEqual(canvas.strokeCount, 1)

        cell.updatePracticeSettings(
            showCrosshair: false,
            allowedTouchTypes: [.pencil],
            brushConfig: BrushStroke.Config(
                pressure: .high, tilt: .off, smoothing: .low, thickness: .thick
            )
        )

        XCTAssertTrue(cell.canvasView === canvas, "Canvas must not be recreated")
        XCTAssertEqual(canvas.strokeCount, 1, "Drawn ink must survive the update")
        XCTAssertEqual(canvas.brushConfig.maxWidth, BrushThickness.thick.widthRange.max)
        XCTAssertEqual(canvas.allowedTouchTypes, [.pencil])
    }

    func testClearGestureRequiresTwoFingerDoubleTap() {
        let cell = NotebookCellView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        cell.configurePractice(
            showCrosshair: true,
            allowedTouchTypes: [.direct, .pencil],
            pressureSensitivity: .off,
            tiltSensitivity: .off,
            smoothingStrength: .medium,
            brushThickness: .medium
        )

        let taps = cell.canvasView?.gestureRecognizers?
            .compactMap { $0 as? UITapGestureRecognizer } ?? []
        XCTAssertEqual(taps.count, 1)
        // Single-finger taps must never clear — they are indistinguishable from
        // drawing consecutive dot strokes (点).
        XCTAssertEqual(taps.first?.numberOfTapsRequired, 2)
        XCTAssertEqual(taps.first?.numberOfTouchesRequired, 2)
    }

    func testUpdatePracticeSettingsIgnoresReferenceCell() {
        let cell = NotebookCellView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        cell.configureReference(kanji: KanjiData(
            codePoint: "4e00",
            element: nil,
            strokes: [],
            components: []
        ))

        XCTAssertNil(cell.canvasView)
        cell.updatePracticeSettings(
            showCrosshair: false,
            allowedTouchTypes: [.pencil],
            brushConfig: BrushStroke.Config(
                pressure: .off, tilt: .off, smoothing: .medium, thickness: .medium
            )
        )
        XCTAssertNil(cell.canvasView)
    }
}

// MARK: - Test Touch Helper

private class TestTouch: UITouch {
    private var _locationInView: CGPoint
    private let _timestamp: TimeInterval

    var touchType: UITouch.TouchType = .direct
    var testForce: CGFloat = 0
    var testAltitude: CGFloat = .pi / 2
    var estimationIndex: NSNumber?
    var expectingUpdates: UITouch.Properties = []

    init(locationInView: CGPoint, timestamp: TimeInterval = 0) {
        _locationInView = locationInView
        _timestamp = timestamp
        super.init()
    }

    func updateLocation(_ point: CGPoint) {
        _locationInView = point
    }

    override func location(in view: UIView?) -> CGPoint {
        _locationInView
    }

    override func preciseLocation(in view: UIView?) -> CGPoint {
        _locationInView
    }

    override var timestamp: TimeInterval { _timestamp }
    override var type: UITouch.TouchType { touchType }
    override var force: CGFloat { testForce }
    override var maximumPossibleForce: CGFloat { 4.17 }
    override var altitudeAngle: CGFloat { testAltitude }
    override var estimationUpdateIndex: NSNumber? { estimationIndex }
    override var estimatedPropertiesExpectingUpdates: UITouch.Properties { expectingUpdates }
}
