import UIKit

/// A UIView that captures touch input and renders strokes as variable-width calligraphy brush paths.
@MainActor
final class DrawingCanvasView: UIView {

    // MARK: - Configuration

    var brushConfig = BrushStroke.Config()
    var strokeColor: UIColor = .label

    // MARK: - Callbacks

    /// Called during drawing when a new point is added. Provides the point and current stroke index.
    var onPointAdded: ((CGPoint, Int) -> Void)?

    /// Called when a stroke is completed (touchesEnded). Provides the raw points and stroke index.
    var onStrokeCompleted: (([CGPoint], Int) -> Void)?

    // MARK: - State

    /// All completed strokes as raw point arrays.
    private(set) var strokes: [[CGPoint]] = []

    /// Points being captured for the current in-progress stroke.
    var currentStrokePoints: [CGPoint] { currentSamples.map(\.point) }

    /// Touch samples (point + timestamp) for the current in-progress stroke.
    private var currentSamples: [BrushStroke.Sample] = []

    /// CAShapeLayers for completed strokes.
    private var strokeLayers: [CAShapeLayer] = []

    /// CAShapeLayer for the stroke currently being drawn.
    private var activeLayer: CAShapeLayer?

    // MARK: - Public API

    /// Returns the total number of completed strokes.
    var strokeCount: Int { strokes.count }

    /// Removes the last completed stroke.
    func removeLastStroke() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        let removed = strokeLayers.removeLast()
        removed.removeFromSuperlayer()
    }

    /// Removes all completed strokes and clears the canvas.
    func clearAll() {
        strokes.removeAll()
        for l in strokeLayers { l.removeFromSuperlayer() }
        strokeLayers.removeAll()
        cancelCurrentStroke()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        currentSamples = [BrushStroke.Sample(point: point, timestamp: touch.timestamp)]

        let shapeLayer = makeBrushLayer()
        layer.addSublayer(shapeLayer)
        activeLayer = shapeLayer

        updateActivePath()
        onPointAdded?(point, strokes.count)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        currentSamples.append(BrushStroke.Sample(point: point, timestamp: touch.timestamp))
        updateActivePath()
        onPointAdded?(point, strokes.count)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if point != currentSamples.last?.point {
            currentSamples.append(BrushStroke.Sample(point: point, timestamp: touch.timestamp))
        }

        finalizeCurrentStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelCurrentStroke()
    }

    // MARK: - Private

    private func makeBrushLayer() -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = strokeColor.cgColor
        shapeLayer.strokeColor = nil
        return shapeLayer
    }

    private func updateActivePath() {
        guard let activeLayer else { return }
        activeLayer.path = BrushStroke.createPath(from: currentSamples, config: brushConfig)
    }

    private func finalizeCurrentStroke() {
        let rawPoints = currentSamples.map(\.point)
        let strokeIndex = strokes.count

        strokes.append(rawPoints)

        if let active = activeLayer {
            active.path = BrushStroke.createPath(from: currentSamples, config: brushConfig)
            strokeLayers.append(active)
            activeLayer = nil
        }

        currentSamples = []
        onStrokeCompleted?(rawPoints, strokeIndex)
    }

    private func cancelCurrentStroke() {
        activeLayer?.removeFromSuperlayer()
        activeLayer = nil
        currentSamples = []
    }
}
