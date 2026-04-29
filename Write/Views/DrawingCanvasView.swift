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
    private var inputFilter = OneEuroFilter()
    private var lastLayoutSize: CGSize = .zero

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

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let newSize = bounds.size
        guard lastLayoutSize.width > 0, lastLayoutSize.height > 0,
              newSize.width > 0, newSize.height > 0,
              newSize != lastLayoutSize else {
            if lastLayoutSize == .zero { lastLayoutSize = newSize }
            return
        }

        let sx = newSize.width / lastLayoutSize.width
        let sy = newSize.height / lastLayoutSize.height
        var transform = CGAffineTransform(scaleX: sx, y: sy)

        for strokeLayer in strokeLayers {
            if let path = strokeLayer.path {
                strokeLayer.path = path.copy(using: &transform)
            }
        }

        strokes = strokes.map { points in
            points.map { CGPoint(x: $0.x * sx, y: $0.y * sy) }
        }

        if let activeLayer, let path = activeLayer.path {
            activeLayer.path = path.copy(using: &transform)
            currentSamples = currentSamples.map {
                BrushStroke.Sample(
                    point: CGPoint(x: $0.point.x * sx, y: $0.point.y * sy),
                    timestamp: $0.timestamp,
                    force: $0.force
                )
            }
        }

        lastLayoutSize = newSize
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
        let rawPoint = touch.location(in: self)
        let force = touch.type == .pencil ? touch.force : nil
        let altitude = touch.type == .pencil ? touch.altitudeAngle : nil

        inputFilter.minCutoff = brushConfig.filterMinCutoff
        inputFilter.beta = brushConfig.filterBeta
        inputFilter.reset()
        let point = inputFilter.filter(point: rawPoint, timestamp: touch.timestamp)

        currentSamples = [BrushStroke.Sample(point: point, timestamp: touch.timestamp, force: force, altitude: altitude)]

        let shapeLayer = makeBrushLayer()
        layer.addSublayer(shapeLayer)
        activeLayer = shapeLayer

        updateActivePath()
        hideHover()
        onPointAdded?(rawPoint, strokes.count)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }

        let allTouches = event?.coalescedTouches(for: touch) ?? [touch]
        for ct in allTouches {
            let rawPoint = ct.location(in: self)
            let cf = ct.type == .pencil ? ct.force : nil
            let ca = ct.type == .pencil ? ct.altitudeAngle : nil
            let point = inputFilter.filter(point: rawPoint, timestamp: ct.timestamp)
            currentSamples.append(BrushStroke.Sample(point: point, timestamp: ct.timestamp, force: cf, altitude: ca))
        }

        updateActivePath()

        if let predicted = event?.predictedTouches(for: touch), !predicted.isEmpty {
            var predictedSamples = currentSamples
            for pt in predicted {
                let pp = pt.location(in: self)
                let pf = pt.type == .pencil ? pt.force : nil
                let pa = pt.type == .pencil ? pt.altitudeAngle : nil
                predictedSamples.append(BrushStroke.Sample(point: pp, timestamp: pt.timestamp, force: pf, altitude: pa))
            }
            updatePredictedPath(samples: predictedSamples)
        } else {
            clearPredicted()
        }

        onPointAdded?(touch.location(in: self), strokes.count)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let rawPoint = touch.location(in: self)
        let force = touch.type == .pencil ? touch.force : nil
        let altitude = touch.type == .pencil ? touch.altitudeAngle : nil
        let point = inputFilter.filter(point: rawPoint, timestamp: touch.timestamp)

        if point != currentSamples.last?.point {
            currentSamples.append(BrushStroke.Sample(point: point, timestamp: touch.timestamp, force: force, altitude: altitude))
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
