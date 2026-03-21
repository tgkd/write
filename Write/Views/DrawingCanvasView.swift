import UIKit

/// A UIView that captures touch input and renders strokes as variable-width calligraphy brush paths.
/// Supports Apple Pencil with pressure sensitivity, predicted touches, hover, and pencil interactions.
@MainActor
final class DrawingCanvasView: UIView, UIPencilInteractionDelegate {

    // MARK: - Configuration

    var brushConfig = BrushStroke.Config()
    var strokeColor: UIColor = .label

    var allowedTouchTypes: Set<UITouch.TouchType> = [.direct, .pencil]

    // MARK: - Callbacks

    var onPointAdded: ((CGPoint, Int) -> Void)?
    var onStrokeCompleted: (([CGPoint], Int) -> Void)?
    var onPencilDoubleTap: (() -> Void)?
    var onPencilSqueeze: (() -> Void)?

    // MARK: - State

    private(set) var strokes: [[CGPoint]] = []
    var currentStrokePoints: [CGPoint] { currentSamples.map(\.point) }
    private var currentSamples: [BrushStroke.Sample] = []
    private var strokeLayers: [CAShapeLayer] = []
    private var activeLayer: CAShapeLayer?
    private var predictedLayer: CAShapeLayer?
    private var hoverLayer: CAShapeLayer?
    private var activeTouch: UITouch?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPencilInteraction()
        setupHoverGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPencilInteraction()
        setupHoverGesture()
    }

    // MARK: - Public API

    var strokeCount: Int { strokes.count }

    func removeLastStroke() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        let removed = strokeLayers.removeLast()
        removed.removeFromSuperlayer()
    }

    func clearAll() {
        strokes.removeAll()
        for l in strokeLayers { l.removeFromSuperlayer() }
        strokeLayers.removeAll()
        cancelCurrentStroke()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil else { return }
        guard let touch = touches.first(where: { allowedTouchTypes.contains($0.type) }) else { return }

        activeTouch = touch
        let point = touch.location(in: self)
        let force = touch.type == .pencil ? touch.force : nil

        currentSamples = [BrushStroke.Sample(point: point, timestamp: touch.timestamp, force: force)]

        let shapeLayer = makeBrushLayer()
        layer.addSublayer(shapeLayer)
        activeLayer = shapeLayer

        updateActivePath()
        hideHover()
        onPointAdded?(point, strokes.count)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let point = touch.location(in: self)
        let force = touch.type == .pencil ? touch.force : nil

        currentSamples.append(BrushStroke.Sample(point: point, timestamp: touch.timestamp, force: force))

        // Coalesce touches for smoother strokes
        if let coalesced = event?.coalescedTouches(for: touch), coalesced.count > 1 {
            for ct in coalesced.dropFirst() {
                let cp = ct.location(in: self)
                let cf = ct.type == .pencil ? ct.force : nil
                currentSamples.append(BrushStroke.Sample(point: cp, timestamp: ct.timestamp, force: cf))
            }
        }

        updateActivePath()

        // Render predicted touches for low-latency visual feedback
        if let predicted = event?.predictedTouches(for: touch), !predicted.isEmpty {
            var predictedSamples = currentSamples
            for pt in predicted {
                let pp = pt.location(in: self)
                let pf = pt.type == .pencil ? pt.force : nil
                predictedSamples.append(BrushStroke.Sample(point: pp, timestamp: pt.timestamp, force: pf))
            }
            updatePredictedPath(samples: predictedSamples)
        } else {
            clearPredicted()
        }

        onPointAdded?(point, strokes.count)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let point = touch.location(in: self)
        let force = touch.type == .pencil ? touch.force : nil

        if point != currentSamples.last?.point {
            currentSamples.append(BrushStroke.Sample(point: point, timestamp: touch.timestamp, force: force))
        }

        clearPredicted()
        finalizeCurrentStroke()
        activeTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        clearPredicted()
        cancelCurrentStroke()
        activeTouch = nil
    }

    // MARK: - Pencil Interaction

    private func setupPencilInteraction() {
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        addInteraction(interaction)
    }

    nonisolated func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        MainActor.assumeIsolated {
            onPencilDoubleTap?()
        }
    }

    // MARK: - Hover

    private func setupHoverGesture() {
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hover)
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            let point = gesture.location(in: self)
            showHover(at: point)
        case .ended, .cancelled:
            hideHover()
        default:
            break
        }
    }

    private func showHover(at point: CGPoint) {
        if hoverLayer == nil {
            let dot = CAShapeLayer()
            dot.fillColor = UIColor.label.withAlphaComponent(0.15).cgColor
            dot.strokeColor = UIColor.label.withAlphaComponent(0.3).cgColor
            dot.lineWidth = 0.5
            layer.addSublayer(dot)
            hoverLayer = dot
        }
        let radius: CGFloat = 4
        hoverLayer?.path = CGPath(
            ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }

    private func hideHover() {
        hoverLayer?.removeFromSuperlayer()
        hoverLayer = nil
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

    private func updatePredictedPath(samples: [BrushStroke.Sample]) {
        if predictedLayer == nil {
            let pl = makeBrushLayer()
            pl.opacity = 0.4
            layer.addSublayer(pl)
            predictedLayer = pl
        }
        predictedLayer?.path = BrushStroke.createPath(from: samples, config: brushConfig)
    }

    private func clearPredicted() {
        predictedLayer?.removeFromSuperlayer()
        predictedLayer = nil
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
