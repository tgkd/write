import UIKit

/// A UIView that captures touch input as stroke point sequences and renders them as smooth curves.
@MainActor
final class DrawingCanvasView: UIView {

    // MARK: - Configuration

    /// Stroke appearance for user-drawn strokes.
    struct StrokeStyle {
        var color: UIColor = .label
        var lineWidth: CGFloat = 4.0
        var lineCap: CAShapeLayerLineCap = .round
        var lineJoin: CAShapeLayerLineJoin = .round
    }

    var strokeStyle = StrokeStyle()

    /// Number of Catmull-Rom subdivisions between control points.
    var smoothingSubdivisions: Int = 8

    /// Catmull-Rom alpha parameter. 0.5 = centripetal (default).
    var smoothingAlpha: CGFloat = 0.5

    // MARK: - Callbacks

    /// Called during drawing when a new point is added. Provides the point and current stroke index.
    var onPointAdded: ((CGPoint, Int) -> Void)?

    /// Called when a stroke is completed (touchesEnded). Provides the raw points and stroke index.
    var onStrokeCompleted: (([CGPoint], Int) -> Void)?

    // MARK: - State

    /// All completed strokes as raw point arrays.
    private(set) var strokes: [[CGPoint]] = []

    /// Points being captured for the current in-progress stroke.
    private(set) var currentStrokePoints: [CGPoint] = []

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

    /// Removes a stroke at a specific index.
    func removeStroke(at index: Int) {
        guard index >= 0 && index < strokes.count else { return }
        strokes.remove(at: index)
        let removed = strokeLayers.remove(at: index)
        removed.removeFromSuperlayer()
    }

    /// Removes all completed strokes and clears the canvas.
    func clearAll() {
        strokes.removeAll()
        for l in strokeLayers { l.removeFromSuperlayer() }
        strokeLayers.removeAll()
        cancelCurrentStroke()
    }

    /// Returns smoothed points for a completed stroke at the given index.
    func smoothedPoints(for strokeIndex: Int) -> [CGPoint] {
        guard strokeIndex >= 0 && strokeIndex < strokes.count else { return [] }
        return CatmullRomSpline.interpolate(
            points: strokes[strokeIndex],
            alpha: smoothingAlpha,
            subdivisions: smoothingSubdivisions
        )
    }

    /// Returns the smoothed CGPath for a completed stroke at the given index.
    func smoothedPath(for strokeIndex: Int) -> CGPath? {
        guard strokeIndex >= 0 && strokeIndex < strokes.count else { return nil }
        return CatmullRomSpline.createPath(
            from: strokes[strokeIndex],
            alpha: smoothingAlpha,
            subdivisions: smoothingSubdivisions
        )
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        currentStrokePoints = [point]

        let shapeLayer = makeStrokeLayer()
        layer.addSublayer(shapeLayer)
        activeLayer = shapeLayer

        updateActivePath()
        onPointAdded?(point, strokes.count)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        currentStrokePoints.append(point)
        updateActivePath()
        onPointAdded?(point, strokes.count)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if point != currentStrokePoints.last {
            currentStrokePoints.append(point)
        }

        finalizeCurrentStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelCurrentStroke()
    }

    // MARK: - Private

    private func makeStrokeLayer() -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.strokeColor = strokeStyle.color.cgColor
        shapeLayer.fillColor = nil
        shapeLayer.lineWidth = strokeStyle.lineWidth
        shapeLayer.lineCap = strokeStyle.lineCap
        shapeLayer.lineJoin = strokeStyle.lineJoin
        return shapeLayer
    }

    private func updateActivePath() {
        guard let activeLayer else { return }
        let path = CatmullRomSpline.createPath(
            from: currentStrokePoints,
            alpha: smoothingAlpha,
            subdivisions: smoothingSubdivisions
        )
        activeLayer.path = path
    }

    private func finalizeCurrentStroke() {
        let rawPoints = currentStrokePoints
        let strokeIndex = strokes.count

        strokes.append(rawPoints)

        if let active = activeLayer {
            let finalPath = CatmullRomSpline.createPath(
                from: rawPoints,
                alpha: smoothingAlpha,
                subdivisions: smoothingSubdivisions
            )
            active.path = finalPath
            strokeLayers.append(active)
            activeLayer = nil
        }

        currentStrokePoints = []
        onStrokeCompleted?(rawPoints, strokeIndex)
    }

    private func cancelCurrentStroke() {
        activeLayer?.removeFromSuperlayer()
        activeLayer = nil
        currentStrokePoints = []
    }
}
