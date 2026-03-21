import UIKit

final class CrosshairGuideLayer: CAShapeLayer {

    override init() {
        super.init()
        strokeColor = UIColor.systemGray4.cgColor
        fillColor = nil
        lineWidth = 0.5
        opacity = 0.6
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func updatePath(for size: CGSize) {
        let path = CGMutablePath()
        let midX = size.width / 2
        let midY = size.height / 2

        path.move(to: CGPoint(x: midX, y: 0))
        path.addLine(to: CGPoint(x: midX, y: size.height))

        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: size.width, y: midY))

        self.path = path
    }
}
