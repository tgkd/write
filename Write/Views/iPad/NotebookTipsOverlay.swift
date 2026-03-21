import UIKit

struct NotebookTip {
    let text: String
    let sourceRect: CGRect
    let arrowDirection: UIPopoverArrowDirection
}

@MainActor
final class NotebookTipsOverlay: UIView {

    private var tips: [NotebookTip] = []
    private var currentIndex = 0
    private let dimView = UIView()
    private let spotlightMask = CAShapeLayer()
    private let bubbleView = UIView()
    private let label = UILabel()
    private let pageLabel = UILabel()
    private var onDismiss: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dimView)

        dimView.layer.mask = spotlightMask

        bubbleView.backgroundColor = .systemBackground
        bubbleView.layer.cornerRadius = 12
        bubbleView.layer.shadowColor = UIColor.black.cgColor
        bubbleView.layer.shadowOpacity = 0.15
        bubbleView.layer.shadowRadius = 12
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 4)
        addSubview(bubbleView)

        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(label)

        pageLabel.font = .systemFont(ofSize: 13)
        pageLabel.textColor = .secondaryLabel
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(pageLabel)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            pageLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            pageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            pageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -14),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(advance))
        addGestureRecognizer(tap)
    }

    func show(tips: [NotebookTip], in parentView: UIView, onDismiss: @escaping () -> Void) {
        guard !tips.isEmpty else { return }
        self.tips = tips
        self.currentIndex = 0
        self.onDismiss = onDismiss
        self.frame = parentView.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.frame = bounds
        parentView.addSubview(self)
        self.alpha = 0
        showCurrentTip()
        UIView.animate(withDuration: 0.25) { self.alpha = 1 }
    }

    @objc private func advance() {
        currentIndex += 1
        if currentIndex >= tips.count {
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
            }) { _ in
                self.removeFromSuperview()
                self.onDismiss?()
            }
        } else {
            showCurrentTip()
        }
    }

    private func showCurrentTip() {
        let tip = tips[currentIndex]
        label.text = tip.text
        pageLabel.text = "\(currentIndex + 1) / \(tips.count)  — tap anywhere"

        updateSpotlight(rect: tip.sourceRect)
        layoutBubble(tip: tip)
    }

    private func updateSpotlight(rect: CGRect) {
        let fullPath = UIBezierPath(rect: bounds)
        let insetRect = rect.insetBy(dx: -6, dy: -6)
        let spotlightPath = UIBezierPath(roundedRect: insetRect, cornerRadius: 8)
        fullPath.append(spotlightPath)
        fullPath.usesEvenOddFillRule = true

        spotlightMask.fillRule = .evenOdd
        spotlightMask.path = fullPath.cgPath
        spotlightMask.frame = bounds
    }

    private func layoutBubble(tip: NotebookTip) {
        let maxWidth: CGFloat = 280
        let padding: CGFloat = 20

        let fitSize = label.sizeThatFits(CGSize(width: maxWidth - 32, height: .greatestFiniteMagnitude))
        let bubbleHeight = fitSize.height + 60
        let bubbleWidth = min(maxWidth, fitSize.width + 32)

        var bubbleX = tip.sourceRect.midX - bubbleWidth / 2
        bubbleX = max(padding, min(bounds.width - bubbleWidth - padding, bubbleX))

        var bubbleY: CGFloat
        if tip.arrowDirection == .up {
            bubbleY = tip.sourceRect.maxY + 12
        } else {
            bubbleY = tip.sourceRect.minY - bubbleHeight - 12
        }
        bubbleY = max(padding, min(bounds.height - bubbleHeight - padding, bubbleY))

        UIView.animate(withDuration: 0.25) {
            self.bubbleView.frame = CGRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight)
        }
    }
}
