import XCTest
@testable import Write

@MainActor
final class StrokeRendererTests: XCTestCase {

    // MARK: - Scale transform

    func testScaleTransformSquareCanvas() {
        let canvasSize = CGSize(width: 300, height: 300)
        let transform = StrokeRenderer.scaleTransform(to: canvasSize)

        let origin = CGPoint.zero.applying(transform)
        XCTAssertEqual(origin.x, 0, accuracy: 0.01)
        XCTAssertEqual(origin.y, 0, accuracy: 0.01)

        let corner = CGPoint(x: 109, y: 109).applying(transform)
        XCTAssertEqual(corner.x, 300, accuracy: 0.01)
        XCTAssertEqual(corner.y, 300, accuracy: 0.01)

        let mid = CGPoint(x: 54.5, y: 54.5).applying(transform)
        XCTAssertEqual(mid.x, 150, accuracy: 0.5)
        XCTAssertEqual(mid.y, 150, accuracy: 0.5)
    }

    func testScaleTransformWideCanvas() {
        let canvasSize = CGSize(width: 400, height: 200)
        let transform = StrokeRenderer.scaleTransform(to: canvasSize)

        let scale = 200.0 / 109.0
        let offsetX = (400.0 - 109.0 * scale) / 2

        let origin = CGPoint.zero.applying(transform)
        XCTAssertEqual(origin.x, offsetX, accuracy: 0.01)
        XCTAssertEqual(origin.y, 0, accuracy: 0.01)

        let corner = CGPoint(x: 109, y: 109).applying(transform)
        XCTAssertEqual(corner.x, offsetX + 109.0 * scale, accuracy: 0.01)
        XCTAssertEqual(corner.y, 200, accuracy: 0.01)
    }

    func testScaleTransformTallCanvas() {
        let canvasSize = CGSize(width: 200, height: 400)
        let transform = StrokeRenderer.scaleTransform(to: canvasSize)

        let scale = 200.0 / 109.0
        let offsetY = (400.0 - 109.0 * scale) / 2

        let origin = CGPoint.zero.applying(transform)
        XCTAssertEqual(origin.x, 0, accuracy: 0.01)
        XCTAssertEqual(origin.y, offsetY, accuracy: 0.01)

        let corner = CGPoint(x: 109, y: 109).applying(transform)
        XCTAssertEqual(corner.x, 200, accuracy: 0.01)
        XCTAssertEqual(corner.y, offsetY + 109.0 * scale, accuracy: 0.01)
    }

    // MARK: - Path creation

    func testCreatePathFromValidData() throws {
        let path = try StrokeRenderer.createPath(from: "M0,0 L50,50")
        XCTAssertFalse(path.boundingBoxOfPath.isEmpty)
    }

    func testCreatePathFromCurveData() throws {
        let path = try StrokeRenderer.createPath(
            from: "M32.01,17c0.09,2.03,0.02,4.65-0.54,6.79"
        )
        XCTAssertFalse(path.boundingBoxOfPath.isEmpty)
    }

    func testCreatePathInvalidDataThrows() {
        XCTAssertThrowsError(try StrokeRenderer.createPath(from: "L"))
    }

    // MARK: - Stroke layer

    func testCreateStrokeLayerDefaultAppearance() throws {
        let stroke = KanjiStroke(
            strokeNumber: 1,
            pathData: "M10,10 L50,50",
            strokeType: nil
        )
        let layer = try StrokeRenderer.createStrokeLayer(
            from: stroke,
            canvasSize: CGSize(width: 300, height: 300)
        )

        XCTAssertNotNil(layer.path)
        XCTAssertNil(layer.fillColor)
        XCTAssertEqual(layer.lineWidth, StrokeAppearance.ghost.lineWidth)
        XCTAssertEqual(layer.lineCap, .round)
        XCTAssertEqual(layer.lineJoin, .round)
    }

    func testCreateStrokeLayerCustomAppearance() throws {
        let stroke = KanjiStroke(
            strokeNumber: 1,
            pathData: "M10,10 L50,50",
            strokeType: nil
        )
        let appearance = StrokeAppearance(
            strokeColor: .blue,
            alpha: 0.7,
            lineWidth: 5.0,
            lineCap: .butt,
            lineJoin: .miter
        )
        let layer = try StrokeRenderer.createStrokeLayer(
            from: stroke,
            canvasSize: CGSize(width: 300, height: 300),
            appearance: appearance
        )

        XCTAssertEqual(layer.lineWidth, 5.0)
        XCTAssertEqual(layer.lineCap, .butt)
        XCTAssertEqual(layer.lineJoin, .miter)
    }

    func testCreateStrokeLayerScalesPath() throws {
        let stroke = KanjiStroke(
            strokeNumber: 1,
            pathData: "M0,0 L109,109",
            strokeType: nil
        )
        let canvasSize = CGSize(width: 300, height: 300)
        let layer = try StrokeRenderer.createStrokeLayer(
            from: stroke,
            canvasSize: canvasSize
        )

        let bounds = layer.path!.boundingBoxOfPath
        XCTAssertGreaterThan(bounds.maxX, 109, "Path should be scaled up from 109 to ~300")
    }

    // MARK: - Animation

    func testDrawingAnimationParameters() throws {
        let stroke = KanjiStroke(
            strokeNumber: 1,
            pathData: "M10,10 L50,50",
            strokeType: nil
        )
        let layer = try StrokeRenderer.createStrokeLayer(
            from: stroke,
            canvasSize: CGSize(width: 300, height: 300)
        )

        StrokeRenderer.addDrawingAnimation(to: layer, duration: 0.8)

        let animation = layer.animation(forKey: "strokeEndAnimation") as? CABasicAnimation
        XCTAssertNotNil(animation)
        XCTAssertEqual(animation?.keyPath, "strokeEnd")
        XCTAssertEqual(animation?.fromValue as? Double, 0)
        XCTAssertEqual(animation?.toValue as? Double, 1)
        XCTAssertEqual(animation?.duration, 0.8)
    }

    func testSequentialAnimationBeginTimes() throws {
        let stroke = KanjiStroke(
            strokeNumber: 1,
            pathData: "M10,10 L50,50",
            strokeType: nil
        )
        let layer1 = try StrokeRenderer.createStrokeLayer(
            from: stroke,
            canvasSize: CGSize(width: 300, height: 300)
        )
        let layer2 = try StrokeRenderer.createStrokeLayer(
            from: stroke,
            canvasSize: CGSize(width: 300, height: 300)
        )

        StrokeRenderer.addDrawingAnimation(to: layer1, duration: 0.5, beginTime: 0)
        StrokeRenderer.addDrawingAnimation(to: layer2, duration: 0.5, beginTime: 0.65)

        let anim1 = layer1.animation(forKey: "strokeEndAnimation") as? CABasicAnimation
        let anim2 = layer2.animation(forKey: "strokeEndAnimation") as? CABasicAnimation

        XCTAssertNotNil(anim1)
        XCTAssertNotNil(anim2)
        XCTAssertGreaterThan(anim2!.beginTime, anim1!.beginTime)
    }
}

@MainActor
final class KanjiReferenceViewTests: XCTestCase {

    private func makeTestKanjiData() -> KanjiData {
        KanjiData(
            codePoint: "5c71",
            element: "山",
            strokes: [
                KanjiStroke(strokeNumber: 1, pathData: "M50,80 L50,30", strokeType: nil),
                KanjiStroke(strokeNumber: 2, pathData: "M25,50 L25,80", strokeType: nil),
                KanjiStroke(strokeNumber: 3, pathData: "M10,80 L90,80", strokeType: nil),
            ],
            components: []
        )
    }

    private func makeConfiguredView() -> KanjiReferenceView {
        let view = KanjiReferenceView(
            frame: CGRect(x: 0, y: 0, width: 300, height: 300)
        )
        view.configure(with: makeTestKanjiData())
        return view
    }

    // MARK: - Stroke count

    func testStrokeCountMatchesKanjiData() {
        let view = makeConfiguredView()
        let data = makeTestKanjiData()
        XCTAssertEqual(view.strokeLayers.count, data.strokes.count)
    }

    // MARK: - Visibility

    func testSetStrokeVisibilityHidden() {
        let view = makeConfiguredView()
        view.setStrokeVisibility(.hidden, at: 0)
        XCTAssertTrue(view.strokeLayers[0].isHidden)
    }

    func testSetStrokeVisibilityVisible() {
        let view = makeConfiguredView()
        view.setStrokeVisibility(.hidden, at: 0)
        view.setStrokeVisibility(.visible(alpha: 0.5), at: 0)
        XCTAssertFalse(view.strokeLayers[0].isHidden)
    }

    func testSetAllStrokesVisibilityHidden() {
        let view = makeConfiguredView()
        view.setAllStrokesVisibility(.hidden)
        for layer in view.strokeLayers {
            XCTAssertTrue(layer.isHidden)
        }
    }

    func testSetAllStrokesVisibilityVisible() {
        let view = makeConfiguredView()
        view.setAllStrokesVisibility(.hidden)
        view.setAllStrokesVisibility(.visible(alpha: 0.4))
        for layer in view.strokeLayers {
            XCTAssertFalse(layer.isHidden)
        }
    }

    // MARK: - Color changes

    func testMarkStrokeAccepted() {
        let view = makeConfiguredView()
        view.markStrokeAccepted(at: 1)
        XCTAssertEqual(view.strokeLayers[1].strokeColor, UIColor.systemGreen.cgColor)
    }

    func testSetStrokeColor() {
        let view = makeConfiguredView()
        view.setStrokeColor(.blue, at: 2)
        XCTAssertEqual(view.strokeLayers[2].strokeColor, UIColor.blue.cgColor)
    }

    func testHighlightStroke() {
        let view = makeConfiguredView()
        view.setStrokeVisibility(.hidden, at: 0)
        view.highlightStroke(at: 0, alpha: 0.5)
        XCTAssertFalse(view.strokeLayers[0].isHidden)
    }

    // MARK: - Animation

    func testAnimateStrokeDrawing() {
        let view = makeConfiguredView()
        view.setStrokeVisibility(.hidden, at: 1)
        view.animateStrokeDrawing(at: 1, duration: 0.6)

        XCTAssertFalse(view.strokeLayers[1].isHidden)
        let animation = view.strokeLayers[1].animation(forKey: "strokeEndAnimation")
        XCTAssertNotNil(animation)
    }

    func testAnimateAllStrokes() {
        let view = makeConfiguredView()
        view.animateAllStrokes(strokeDuration: 0.3, delay: 0.1)

        for layer in view.strokeLayers {
            XCTAssertFalse(layer.isHidden)
            XCTAssertNotNil(layer.animation(forKey: "strokeEndAnimation"))
        }
    }

    // MARK: - Safety

    func testInvalidIndexDoesNotCrash() {
        let view = makeConfiguredView()
        view.setStrokeVisibility(.hidden, at: -1)
        view.setStrokeVisibility(.hidden, at: 100)
        view.markStrokeAccepted(at: -1)
        view.setStrokeColor(.red, at: 100)
        view.highlightStroke(at: -1)
        view.flashStrokeRejected(at: 100)
        view.animateStrokeDrawing(at: -1)
    }

    // MARK: - Reconfigure

    func testReconfigureRebuildsLayers() {
        let view = makeConfiguredView()
        XCTAssertEqual(view.strokeLayers.count, 3)

        let twoStrokeData = KanjiData(
            codePoint: "4e00",
            element: "一",
            strokes: [
                KanjiStroke(strokeNumber: 1, pathData: "M10,50 L90,50", strokeType: nil),
            ],
            components: []
        )
        view.configure(with: twoStrokeData)
        XCTAssertEqual(view.strokeLayers.count, 1)
    }
}
