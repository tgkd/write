import UIKit

@MainActor
final class FeedbackOverlayView: UIView {

    private var feedbackLayers: [CAShapeLayer] = []
    var acceptedColor: UIColor = .systemGreen
    var rejectedColor: UIColor = .systemRed

    func showAccepted(points: [CGPoint]) {
        guard points.count >= 2 else { return }
        let path = CatmullRomSpline.createPath(from: points)
        let shapeLayer = makeLayer(path: path, color: acceptedColor)
        layer.addSublayer(shapeLayer)
        feedbackLayers.append(shapeLayer)
        animateAndRemove(layer: shapeLayer, totalDuration: 0.6)
    }

    func showRejected(points: [CGPoint]) {
        guard points.count >= 2 else { return }
        let path = CatmullRomSpline.createPath(from: points)
        let shapeLayer = makeLayer(path: path, color: rejectedColor)
        layer.addSublayer(shapeLayer)
        feedbackLayers.append(shapeLayer)
        animateAndRemove(layer: shapeLayer, totalDuration: 0.4)
    }

    func clearAll() {
        feedbackLayers.forEach { $0.removeFromSuperlayer() }
        feedbackLayers.removeAll()
    }

    // MARK: - Private

    private func makeLayer(path: CGPath, color: UIColor) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.fillColor = nil
        shapeLayer.lineWidth = 4.0
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        return shapeLayer
    }

    private func animateAndRemove(layer shapeLayer: CAShapeLayer, totalDuration: TimeInterval) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak shapeLayer] in
            shapeLayer?.removeFromSuperlayer()
            if let shapeLayer {
                self?.feedbackLayers.removeAll { $0 === shapeLayer }
            }
        }
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1.0, 1.0, 0.0]
        fade.keyTimes = [0.0, 0.4, 1.0] as [NSNumber]
        fade.duration = totalDuration
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        shapeLayer.add(fade, forKey: "fadeOut")
        CATransaction.commit()
    }
}
