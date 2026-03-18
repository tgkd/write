import UIKit

class KanjiReferenceView: UIView {
    enum StrokeVisibility {
        case hidden
        case visible(alpha: CGFloat)
    }

    private(set) var strokeLayers: [CAShapeLayer] = []
    private var kanjiData: KanjiData?
    private var lastBuiltSize: CGSize = .zero
    var onLayersRebuilt: (() -> Void)?

    func configure(with kanjiData: KanjiData) {
        self.kanjiData = kanjiData
        lastBuiltSize = .zero
        rebuildStrokeLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if kanjiData != nil && bounds.size != lastBuiltSize {
            rebuildStrokeLayers()
        }
    }

    private func rebuildStrokeLayers() {
        strokeLayers.forEach { $0.removeFromSuperlayer() }
        strokeLayers.removeAll()

        guard let kanjiData, !bounds.isEmpty else { return }
        lastBuiltSize = bounds.size

        for stroke in kanjiData.strokes {
            if let layer = try? StrokeRenderer.createStrokeLayer(
                from: stroke,
                canvasSize: bounds.size
            ) {
                self.layer.addSublayer(layer)
                strokeLayers.append(layer)
            }
        }

        onLayersRebuilt?()
    }

    // MARK: - Visibility control

    func setStrokeVisibility(_ visibility: StrokeVisibility, at index: Int) {
        guard strokeLayers.indices.contains(index) else { return }
        let layer = strokeLayers[index]
        switch visibility {
        case .hidden:
            layer.isHidden = true
        case .visible(let alpha):
            layer.isHidden = false
            layer.strokeColor = UIColor.gray.withAlphaComponent(alpha).cgColor
        }
    }

    func setAllStrokesVisibility(_ visibility: StrokeVisibility) {
        for i in strokeLayers.indices {
            setStrokeVisibility(visibility, at: i)
        }
    }

    // MARK: - Color changes

    func setStrokeColor(_ color: UIColor, at index: Int) {
        guard strokeLayers.indices.contains(index) else { return }
        strokeLayers[index].strokeColor = color.cgColor
    }

    func highlightStroke(at index: Int, alpha: CGFloat = 0.5) {
        guard strokeLayers.indices.contains(index) else { return }
        let layer = strokeLayers[index]
        layer.isHidden = false
        layer.strokeColor = UIColor.gray.withAlphaComponent(alpha).cgColor
    }

    func markStrokeAccepted(at index: Int) {
        guard strokeLayers.indices.contains(index) else { return }
        strokeLayers[index].isHidden = false
        strokeLayers[index].strokeColor = UIColor.systemGreen.cgColor
    }

    func flashStrokeRejected(at index: Int, duration: CFTimeInterval = 0.5) {
        guard strokeLayers.indices.contains(index) else { return }
        let layer = strokeLayers[index]
        layer.isHidden = false

        let originalColor = layer.strokeColor
        layer.strokeColor = UIColor.systemRed.cgColor

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak layer] in
            layer?.strokeColor = originalColor
        }
        let animation = CABasicAnimation(keyPath: "strokeColor")
        animation.fromValue = UIColor.systemRed.cgColor
        animation.toValue = originalColor
        animation.duration = duration
        layer.add(animation, forKey: "rejectedFlash")
        CATransaction.commit()
    }

    // MARK: - Stroke drawing animation

    func animateStrokeDrawing(at index: Int, duration: CFTimeInterval = 0.5) {
        guard strokeLayers.indices.contains(index) else { return }
        strokeLayers[index].isHidden = false
        StrokeRenderer.addDrawingAnimation(to: strokeLayers[index], duration: duration)
    }

    func animateAllStrokes(strokeDuration: CFTimeInterval = 0.3, delay: CFTimeInterval = 0.15) {
        for (i, layer) in strokeLayers.enumerated() {
            layer.isHidden = false
            let beginTime = Double(i) * (strokeDuration + delay)
            StrokeRenderer.addDrawingAnimation(
                to: layer,
                duration: strokeDuration,
                beginTime: beginTime
            )
        }
    }
}
