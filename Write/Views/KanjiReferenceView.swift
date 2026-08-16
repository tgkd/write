import UIKit

class KanjiReferenceView: UIView {
    enum StrokeVisibility {
        case hidden
        case visible(alpha: CGFloat)
    }

    /// Display state of one reference stroke. Kept outside the layers so a
    /// layer rebuild (resize) can restore it synchronously instead of flashing
    /// every stroke at default appearance until an async re-apply runs.
    private enum StrokeDisplayState {
        case hidden
        case visible(alpha: CGFloat)
        case accepted
    }

    private(set) var strokeLayers: [CAShapeLayer] = []
    private var kanjiData: KanjiData?
    private var lastBuiltSize: CGSize = .zero
    private var strokeStates: [Int: StrokeDisplayState] = [:]
    var onLayersRebuilt: (() -> Void)?
    var strokeLineWidth: CGFloat = 5.0
    var colorProvider: (Int, Int) -> UIColor = StrokeAppearance.strokeOrderColor

    func configure(with kanjiData: KanjiData) {
        self.kanjiData = kanjiData
        lastBuiltSize = .zero
        strokeStates.removeAll()
        rebuildStrokeLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if kanjiData != nil && bounds.size != lastBuiltSize {
            rebuildStrokeLayers()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        // Stroke colors are resolved CGColors; re-resolve for the new style.
        traitCollection.performAsCurrent {
            for index in strokeLayers.indices {
                applyDisplayState(at: index)
            }
        }
    }

    private func rebuildStrokeLayers() {
        strokeLayers.forEach { $0.removeFromSuperlayer() }
        strokeLayers.removeAll()

        guard let kanjiData, !bounds.isEmpty else { return }
        lastBuiltSize = bounds.size

        let total = kanjiData.strokes.count
        for (index, stroke) in kanjiData.strokes.enumerated() {
            let color = colorProvider(index, total)
            let appearance = StrokeAppearance(strokeColor: color, lineWidth: strokeLineWidth)
            if let layer = try? StrokeRenderer.createStrokeLayer(
                from: stroke,
                canvasSize: bounds.size,
                appearance: appearance
            ) {
                layer.contentsScale = self.layer.contentsScale
                self.layer.addSublayer(layer)
                strokeLayers.append(layer)
            }
        }

        for index in strokeStates.keys {
            applyDisplayState(at: index)
        }

        onLayersRebuilt?()
    }

    func updateAppearance(lineWidth: CGFloat, colorProvider: @escaping (Int, Int) -> UIColor) {
        self.strokeLineWidth = lineWidth
        self.colorProvider = colorProvider
        for (index, layer) in strokeLayers.enumerated() {
            layer.lineWidth = lineWidth
            applyDisplayState(at: index)
        }
    }

    // MARK: - Visibility control

    func setStrokeVisibility(_ visibility: StrokeVisibility, at index: Int) {
        guard strokeLayers.indices.contains(index) else { return }
        switch visibility {
        case .hidden:
            strokeStates[index] = .hidden
        case .visible(let alpha):
            strokeStates[index] = .visible(alpha: alpha)
        }
        applyDisplayState(at: index)
    }

    // MARK: - Color changes

    func highlightStroke(at index: Int, alpha: CGFloat = 0.5) {
        guard strokeLayers.indices.contains(index) else { return }
        strokeStates[index] = .visible(alpha: alpha)
        applyDisplayState(at: index)
    }

    func markStrokeAccepted(at index: Int) {
        guard strokeLayers.indices.contains(index) else { return }
        strokeStates[index] = .accepted
        applyDisplayState(at: index)
    }

    // MARK: - Stroke drawing animation

    func animateStrokeDrawing(at index: Int, duration: CFTimeInterval = 0.5) {
        guard strokeLayers.indices.contains(index) else { return }
        strokeLayers[index].isHidden = false
        StrokeRenderer.addDrawingAnimation(to: strokeLayers[index], duration: duration)
    }

    // MARK: - Private

    private func applyDisplayState(at index: Int) {
        guard strokeLayers.indices.contains(index) else { return }
        let layer = strokeLayers[index]
        let color = orderColor(at: index)
        switch strokeStates[index] {
        case .none:
            layer.isHidden = false
            layer.strokeColor = color.withAlphaComponent(StrokeAppearance.ghost.alpha).cgColor
        case .hidden:
            layer.isHidden = true
        case .visible(let alpha):
            layer.isHidden = false
            layer.strokeColor = color.withAlphaComponent(alpha).cgColor
        case .accepted:
            layer.isHidden = false
            layer.strokeColor = color.cgColor
        }
    }

    private func orderColor(at index: Int) -> UIColor {
        colorProvider(index, strokeLayers.count)
    }
}
