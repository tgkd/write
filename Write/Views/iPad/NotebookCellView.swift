import UIKit

@MainActor
final class NotebookCellView: UICollectionViewCell {

    static let reuseIdentifier = "NotebookCellView"

    var showCrosshair: Bool = true {
        didSet { crosshairLayer.isHidden = !showCrosshair }
    }

    private let crosshairLayer = CrosshairGuideLayer()
    private var canvasView: DrawingCanvasView?

    // MARK: - Reference state

    private var referenceLayers: [CAShapeLayer] = []
    private var referenceKanji: KanjiData?
    private var lastReferenceSize: CGSize = .zero
    private var isAnimating = false
    private var referenceTapGesture: UITapGestureRecognizer?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.clipsToBounds = true
        contentView.layer.addSublayer(crosshairLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        crosshairLayer.frame = contentView.bounds
        crosshairLayer.updatePath(for: contentView.bounds.size)
        canvasView?.frame = contentView.bounds
        rebuildReferenceLayers()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        removeCanvas()
        crosshairLayer.isHidden = false
        contentView.isUserInteractionEnabled = true
        contentView.backgroundColor = .clear
        for layer in referenceLayers { layer.removeFromSuperlayer() }
        referenceLayers.removeAll()
        referenceKanji = nil
        lastReferenceSize = .zero
        isAnimating = false
        if let gesture = referenceTapGesture {
            contentView.removeGestureRecognizer(gesture)
            referenceTapGesture = nil
        }
    }

    // MARK: - Reference Cell

    func configureReference(kanji: KanjiData) {
        removeCanvas()
        showCrosshair = true
        contentView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.3)
        contentView.isUserInteractionEnabled = true
        isAnimating = false
        referenceKanji = kanji
        lastReferenceSize = .zero
        rebuildReferenceLayers()

        if referenceTapGesture == nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleReferenceTap))
            contentView.addGestureRecognizer(tap)
            referenceTapGesture = tap
        }
    }

    @objc private func handleReferenceTap() {
        guard referenceKanji != nil, !isAnimating else { return }
        playStrokeOrderAnimation()
    }

    private func playStrokeOrderAnimation() {
        guard !referenceLayers.isEmpty else { return }
        isAnimating = true

        for layer in referenceLayers {
            layer.strokeEnd = 0
        }

        let strokeDuration: CFTimeInterval = 0.4
        let gap: CFTimeInterval = 0.15
        let now = CACurrentMediaTime()

        for (i, layer) in referenceLayers.enumerated() {
            let delay = Double(i) * (strokeDuration + gap)
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = 0
            anim.toValue = 1
            anim.duration = strokeDuration
            anim.beginTime = now + delay
            anim.fillMode = .both
            anim.isRemovedOnCompletion = false
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(anim, forKey: "strokeOrder")
        }

        let totalDuration = Double(referenceLayers.count) * (strokeDuration + gap)
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.3) { [weak self] in
            guard let self else { return }
            for layer in self.referenceLayers {
                layer.removeAnimation(forKey: "strokeOrder")
                layer.strokeEnd = 1
            }
            self.isAnimating = false
        }
    }

    private func rebuildReferenceLayers() {
        guard let kanji = referenceKanji else { return }
        let size = contentView.bounds.size
        guard size.width > 0, size != lastReferenceSize else { return }
        lastReferenceSize = size

        for layer in referenceLayers { layer.removeFromSuperlayer() }
        referenceLayers.removeAll()

        for stroke in kanji.strokes {
            if let layer = try? StrokeRenderer.createStrokeLayer(
                from: stroke,
                canvasSize: size,
                appearance: StrokeAppearance(strokeColor: .label, alpha: 0.7, lineWidth: 3.0)
            ) {
                contentView.layer.addSublayer(layer)
                referenceLayers.append(layer)
            }
        }
    }

    // MARK: - Practice Cell

    func configurePractice(
        showCrosshair: Bool,
        allowedTouchTypes: Set<UITouch.TouchType>,
        pressureSensitivity: PressureSensitivity
    ) {
        self.showCrosshair = showCrosshair
        contentView.backgroundColor = .clear
        installCanvas(allowedTouchTypes: allowedTouchTypes, pressureSensitivity: pressureSensitivity)
    }

    // MARK: - Canvas

    private func installCanvas(
        allowedTouchTypes: Set<UITouch.TouchType>,
        pressureSensitivity: PressureSensitivity
    ) {
        if canvasView != nil { return }

        let canvas = DrawingCanvasView(frame: contentView.bounds)
        canvas.backgroundColor = .clear
        canvas.allowedTouchTypes = allowedTouchTypes
        canvas.brushConfig.pressureSensitivity = pressureSensitivity
        canvas.onPencilDoubleTap = { [weak canvas] in
            canvas?.clearAll()
        }
        contentView.addSubview(canvas)
        canvasView = canvas

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        canvas.addGestureRecognizer(doubleTap)
    }

    private func removeCanvas() {
        canvasView?.removeFromSuperview()
        canvasView = nil
    }

    @objc private func handleDoubleTap() {
        canvasView?.clearAll()
    }
}
