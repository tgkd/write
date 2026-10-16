import UIKit

/// A UIView that captures touch input and renders strokes as variable-width calligraphy brush paths.
/// Supports Apple Pencil with pressure sensitivity, predicted touches, and hover.
/// Pencil hardware interactions (double-tap) are owned by the hosting screen,
/// not the canvas, so a screen with many canvases installs only one interaction.
@MainActor
final class DrawingCanvasView: UIView {

    // MARK: - Configuration

    var brushConfig = BrushStroke.Config()
    var strokeColor: UIColor = .label

    var allowedTouchTypes: Set<UITouch.TouchType> = [.direct, .pencil]

    // MARK: - Callbacks

    var onPointAdded: ((CGPoint, Int) -> Void)?
    var onPencilStrokeBegan: (() -> Void)?
    var onStrokeCompleted: (([CGPoint], Int) -> Void)?
    var onStrokeCaptured: ((CanvasStrokeCapture) -> Void)?

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
    private var liveRenderer: BrushStroke.LiveRenderer?
    private var lastLayoutSize: CGSize = .zero

    /// Pencil force/altitude arrive as estimates and are refined a few frames
    /// later via touchesEstimatedPropertiesUpdated. Maps estimationUpdateIndex
    /// to the index of the sample it refines.
    private var activeEstimationIndexMap: [NSNumber: Int] = [:]
    /// Refinements for the most recently finalized stroke, which can still
    /// arrive after touchesEnded. Dropped when the next stroke begins.
    private var pendingRefinement: (samples: [BrushStroke.Sample], layer: CAShapeLayer, indexMap: [NSNumber: Int])?

    private struct PendingCapture {
        let id: UUID
        let touchType: UITouch.TouchType
        let canvasSize: CGSize
        var samples: [BrushStroke.Sample]
        var outstanding: [NSNumber: Int]
        let handler: (CanvasStrokeCapture) -> Void
        var didRefine = false

        var capture: CanvasStrokeCapture {
            CanvasStrokeCapture(id: id, touchType: touchType, canvasSize: canvasSize, samples: samples)
        }
    }

    private var captureSamples: [BrushStroke.Sample] = []
    private var captureOutstanding: [NSNumber: Int] = [:]
    private var pendingCapture: PendingCapture?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        setupHoverGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
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

        // A mid-stroke resize cannot be rescaled consistently: the input
        // filter's state and the live renderer stay in the old coordinate
        // space. Cancel the in-flight stroke instead of distorting it.
        if activeTouch != nil || activeLayer != nil {
            cancelCurrentStroke()
        }
        // Pending refinement samples are in the old space too; the layer path
        // was rescaled above, so a late re-render would undo the rescale.
        pendingRefinement = nil

        lastLayoutSize = newSize
    }

    // MARK: - Trait changes

    /// Layer colors are resolved CGColors; re-resolve them when the interface
    /// style flips or committed ink keeps the previous appearance's color.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }

        let resolved = strokeColor.resolvedColor(with: traitCollection).cgColor
        for strokeLayer in strokeLayers { strokeLayer.fillColor = resolved }
        activeLayer?.fillColor = resolved
        predictedLayer?.fillColor = resolved
        if let hover = hoverLayer {
            hover.fillColor = UIColor.label.withAlphaComponent(0.15)
                .resolvedColor(with: traitCollection).cgColor
            hover.strokeColor = UIColor.label.withAlphaComponent(0.3)
                .resolvedColor(with: traitCollection).cgColor
        }
    }

    // MARK: - Public API

    var strokeCount: Int { strokes.count }

    func removeLastStroke() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        let removed = strokeLayers.removeLast()
        removed.removeFromSuperlayer()
        if pendingRefinement?.layer === removed {
            pendingRefinement = nil
        }
    }

    func clearAll() {
        strokes.removeAll()
        for l in strokeLayers { l.removeFromSuperlayer() }
        strokeLayers.removeAll()
        pendingRefinement = nil
        cancelCurrentStroke()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        var takeoverTouch: UITouch?
        if let current = activeTouch {
            // A Pencil takes over from an active finger stroke (typically a
            // resting palm that claimed the touch first); the palm ink is
            // discarded. Nothing interrupts a Pencil stroke.
            guard current.type == .direct,
                  allowedTouchTypes.contains(.pencil),
                  let pencil = touches.first(where: { $0.type == .pencil }) else { return }
            cancelCurrentStroke()
            takeoverTouch = pencil
        }
        guard let touch = takeoverTouch ?? preferredTouch(from: touches) else { return }

        activeTouch = touch
        let rawPoint = location(of: touch)
        let force = normalizedForce(of: touch)
        let altitude = touch.type == .pencil ? touch.altitudeAngle : nil

        inputFilter.minCutoff = brushConfig.filterMinCutoff
        inputFilter.beta = brushConfig.filterBeta
        inputFilter.reset()
        let point = inputFilter.filter(point: rawPoint, timestamp: touch.timestamp)

        pendingRefinement = nil
        activeEstimationIndexMap = [:]
        endPendingCapture()
        let sample = BrushStroke.Sample(point: point, timestamp: touch.timestamp, force: force, altitude: altitude)
        currentSamples = [sample]
        liveRenderer = BrushStroke.LiveRenderer(config: brushConfig)
        liveRenderer?.append(sample)
        recordEstimationIndex(for: touch, sampleIndex: 0)
        captureSamples = []
        captureOutstanding = [:]
        appendCaptureSample(for: touch, rawPoint: rawPoint, force: force, altitude: altitude)

        let shapeLayer = makeBrushLayer()
        layer.addSublayer(shapeLayer)
        activeLayer = shapeLayer

        updateActivePath()
        hideHover()
        if touch.type == .pencil {
            onPencilStrokeBegan?()
        }
        onPointAdded?(point, strokes.count)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }

        let allTouches = event?.coalescedTouches(for: touch) ?? [touch]
        for ct in allTouches {
            let rawPoint = location(of: ct)
            let cf = normalizedForce(of: ct)
            let ca = ct.type == .pencil ? ct.altitudeAngle : nil
            let point = inputFilter.filter(point: rawPoint, timestamp: ct.timestamp)
            let sample = BrushStroke.Sample(point: point, timestamp: ct.timestamp, force: cf, altitude: ca)
            currentSamples.append(sample)
            liveRenderer?.append(sample)
            recordEstimationIndex(for: ct, sampleIndex: currentSamples.count - 1)
            appendCaptureSample(for: ct, rawPoint: rawPoint, force: cf, altitude: ca)
        }

        updateActivePath()

        if let predicted = event?.predictedTouches(for: touch), !predicted.isEmpty {
            var predictionFilter = inputFilter
            var predictedSamples: [BrushStroke.Sample] = []
            for pt in predicted {
                let pp = predictionFilter.filter(point: location(of: pt), timestamp: pt.timestamp)
                let pf = normalizedForce(of: pt)
                let pa = pt.type == .pencil ? pt.altitudeAngle : nil
                predictedSamples.append(BrushStroke.Sample(point: pp, timestamp: pt.timestamp, force: pf, altitude: pa))
            }
            updatePredictedPath(predictedSamples: predictedSamples)
        } else {
            clearPredicted()
        }

        if let point = currentSamples.last?.point {
            onPointAdded?(point, strokes.count)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }

        // The final event carries coalesced samples too — the stroke tail is
        // where taper detail matters most.
        let allTouches = event?.coalescedTouches(for: touch) ?? [touch]
        for ct in allTouches {
            let rawPoint = location(of: ct)
            let cf = normalizedForce(of: ct)
            let ca = ct.type == .pencil ? ct.altitudeAngle : nil
            let point = inputFilter.filter(point: rawPoint, timestamp: ct.timestamp)
            if point != currentSamples.last?.point {
                let sample = BrushStroke.Sample(point: point, timestamp: ct.timestamp, force: cf, altitude: ca)
                currentSamples.append(sample)
                liveRenderer?.append(sample)
                recordEstimationIndex(for: ct, sampleIndex: currentSamples.count - 1)
                appendCaptureSample(for: ct, rawPoint: rawPoint, force: cf, altitude: ca)
            }
        }

        clearPredicted()
        finalizeCurrentStroke()
        activeTouch = nil
        hideHover()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        cancelCurrentStroke()
    }

    /// Applies refined force/altitude values that UIKit delivers after the
    /// original estimates. Only brush geometry is refined — stroke POINTS are
    /// never touched, since they have already been handed to validation.
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        var activeNeedsRender = false
        for touch in touches {
            guard let key = touch.estimationUpdateIndex, touch.type == .pencil else { continue }
            let force = normalizedForce(of: touch)
            let altitude = touch.altitudeAngle

            if let idx = activeEstimationIndexMap[key], currentSamples.indices.contains(idx) {
                let old = currentSamples[idx]
                currentSamples[idx] = BrushStroke.Sample(
                    point: old.point, timestamp: old.timestamp, force: force, altitude: altitude
                )
                liveRenderer?.refine(rawIndex: idx, force: force, altitude: altitude)
                activeNeedsRender = true
            } else if var pending = pendingRefinement,
                      let idx = pending.indexMap[key],
                      pending.samples.indices.contains(idx) {
                let old = pending.samples[idx]
                pending.samples[idx] = BrushStroke.Sample(
                    point: old.point, timestamp: old.timestamp, force: force, altitude: altitude
                )
                pendingRefinement = pending
                pending.layer.path = BrushStroke.createPath(from: pending.samples, config: brushConfig)
            }
            refineCapture(with: touch, key: key, force: force, altitude: altitude)
        }
        if activeNeedsRender {
            updateActivePath()
        }
    }

    // MARK: - Hover

    private func setupHoverGesture() {
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hover)
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        if activeTouch != nil {
            hideHover()
            return
        }
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
            dot.contentsScale = layer.contentsScale
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

    private func preferredTouch(from touches: Set<UITouch>) -> UITouch? {
        if allowedTouchTypes.contains(.pencil),
           let pencil = touches.first(where: { $0.type == .pencil }) {
            return pencil
        }
        return touches.first(where: { allowedTouchTypes.contains($0.type) })
    }

    /// Returns the most precise location available for a touch.
    /// Apple Pencil reports sub-point coordinates via `preciseLocation`, avoiding the
    /// 1pt-grid quantization jitter of `location(in:)`. Finger touches are identical.
    private func location(of touch: UITouch) -> CGPoint {
        touch.type == .pencil ? touch.preciseLocation(in: self) : touch.location(in: self)
    }

    /// Pencil force normalized to 0…1 of the device's maximum, nil for fingers.
    private func normalizedForce(of touch: UITouch) -> CGFloat? {
        guard touch.type == .pencil else { return nil }
        return touch.force / max(touch.maximumPossibleForce, 0.0001)
    }

    /// Remembers which sample a future estimated-property update will refine.
    /// Skipped when neither pressure nor tilt can affect rendering.
    private func recordEstimationIndex(for touch: UITouch, sampleIndex: Int) {
        guard touch.type == .pencil,
              brushConfig.pressureSensitivity != .off || brushConfig.tiltSensitivity != .off,
              !touch.estimatedPropertiesExpectingUpdates.isEmpty,
              let key = touch.estimationUpdateIndex else { return }
        activeEstimationIndexMap[key] = sampleIndex
    }

    private func appendCaptureSample(for touch: UITouch, rawPoint: CGPoint, force: CGFloat?, altitude: CGFloat?) {
        guard onStrokeCaptured != nil else {
            return
        }
        captureSamples.append(
            BrushStroke.Sample(point: rawPoint, timestamp: touch.timestamp, force: force, altitude: altitude)
        )
        guard touch.type == .pencil,
              !touch.estimatedPropertiesExpectingUpdates.isEmpty,
              let key = touch.estimationUpdateIndex else {
            return
        }
        captureOutstanding[key] = captureSamples.count - 1
    }

    private func refineCapture(with touch: UITouch, key: NSNumber, force: CGFloat?, altitude: CGFloat) {
        let isFinal = touch.estimatedPropertiesExpectingUpdates.isEmpty
        if let idx = captureOutstanding[key], captureSamples.indices.contains(idx) {
            captureSamples[idx] = refined(captureSamples[idx], force: force, altitude: altitude)
            if isFinal {
                captureOutstanding[key] = nil
            }
            return
        }
        guard var pending = pendingCapture,
              let idx = pending.outstanding[key],
              pending.samples.indices.contains(idx) else {
            return
        }
        pending.samples[idx] = refined(pending.samples[idx], force: force, altitude: altitude)
        pending.didRefine = true
        if isFinal {
            pending.outstanding[key] = nil
        }
        if pending.outstanding.isEmpty {
            pendingCapture = nil
            pending.handler(pending.capture)
        } else {
            pendingCapture = pending
        }
    }

    private func refined(_ sample: BrushStroke.Sample, force: CGFloat?, altitude: CGFloat) -> BrushStroke.Sample {
        BrushStroke.Sample(point: sample.point, timestamp: sample.timestamp, force: force, altitude: altitude)
    }

    private func endPendingCapture() {
        guard let pending = pendingCapture else {
            return
        }
        pendingCapture = nil
        if pending.didRefine {
            pending.handler(pending.capture)
        }
    }

    private func emitCapture(touchType: UITouch.TouchType) {
        defer {
            captureSamples = []
            captureOutstanding = [:]
        }
        guard let onStrokeCaptured, !captureSamples.isEmpty else {
            return
        }
        let pending = PendingCapture(
            id: UUID(),
            touchType: touchType,
            canvasSize: bounds.size,
            samples: captureSamples,
            outstanding: captureOutstanding,
            handler: onStrokeCaptured
        )
        if !pending.outstanding.isEmpty {
            pendingCapture = pending
        }
        onStrokeCaptured(pending.capture)
    }

    private func makeBrushLayer() -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.contentsScale = layer.contentsScale
        shapeLayer.fillColor = strokeColor.cgColor
        shapeLayer.strokeColor = nil
        shapeLayer.actions = ["path": NSNull()]
        return shapeLayer
    }

    private func updateActivePath() {
        guard let activeLayer else { return }
        activeLayer.path = liveRenderer?.currentPath()
            ?? BrushStroke.createPath(from: currentSamples, config: brushConfig)
    }

    private func updatePredictedPath(predictedSamples: [BrushStroke.Sample]) {
        guard let liveRenderer else { return }
        if predictedLayer == nil {
            let pl = makeBrushLayer()
            pl.opacity = 0.4
            layer.addSublayer(pl)
            predictedLayer = pl
        }
        predictedLayer?.path = liveRenderer.predictedPath(with: predictedSamples)
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
            if !activeEstimationIndexMap.isEmpty {
                pendingRefinement = (currentSamples, active, activeEstimationIndexMap)
            }
            activeLayer = nil
        }

        activeEstimationIndexMap = [:]
        currentSamples = []
        liveRenderer = nil
        emitCapture(touchType: activeTouch?.type ?? .direct)
        onStrokeCompleted?(rawPoints, strokeIndex)
    }

    private func cancelCurrentStroke() {
        activeTouch = nil
        hideHover()
        clearPredicted()
        activeLayer?.removeFromSuperlayer()
        activeLayer = nil
        currentSamples = []
        liveRenderer = nil
        activeEstimationIndexMap = [:]
        captureSamples = []
        captureOutstanding = [:]
    }
}
