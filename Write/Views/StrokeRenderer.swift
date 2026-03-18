import UIKit
import SVGPath

struct StrokeAppearance: Sendable {
    var strokeColor: UIColor = .gray
    var alpha: CGFloat = 0.3
    var lineWidth: CGFloat = 5.0
    var lineCap: CAShapeLayerLineCap = .round
    var lineJoin: CAShapeLayerLineJoin = .round

    static let ghost = StrokeAppearance()
    static let currentGhost = StrokeAppearance(alpha: 0.5, lineWidth: 6.0)

    /// Returns a color for the given stroke index within a total stroke count.
    /// Produces a warm gradient: red → orange → yellow → green.
    static func strokeOrderColor(index: Int, total: Int) -> UIColor {
        guard total > 1 else {
            return UIColor(hue: 0.0, saturation: 0.60, brightness: 0.75, alpha: 1)
        }
        let hue = CGFloat(index) / CGFloat(total - 1) * 0.33
        return UIColor(hue: hue, saturation: 0.60, brightness: 0.75, alpha: 1)
    }
}

enum StrokeRenderer {
    static let kanjiVGSize: CGFloat = 109

    /// Computes a uniform scale transform from the 109x109 KanjiVG coordinate space
    /// to the given canvas size, centering the content.
    static func scaleTransform(to canvasSize: CGSize) -> CGAffineTransform {
        let scale = min(canvasSize.width, canvasSize.height) / kanjiVGSize
        let scaledSize = kanjiVGSize * scale
        let offsetX = (canvasSize.width - scaledSize) / 2
        let offsetY = (canvasSize.height - scaledSize) / 2
        return CGAffineTransform(translationX: offsetX, y: offsetY)
            .scaledBy(x: scale, y: scale)
    }

    /// Parses an SVG path string into a CGPath without Y-axis inversion
    /// (KanjiVG and CAShapeLayer both use top-left origin, Y-down).
    static func createPath(from pathData: String) throws -> CGPath {
        let options = SVGPath.ParseOptions(invertYAxis: false)
        let svgPath = try SVGPath(string: pathData, with: options)
        return CGPath.from(svgPath)
    }

    /// Creates a CAShapeLayer for a single stroke, scaled to the given canvas size.
    @MainActor
    static func createStrokeLayer(
        from stroke: KanjiStroke,
        canvasSize: CGSize,
        appearance: StrokeAppearance = .ghost
    ) throws -> CAShapeLayer {
        let cgPath = try createPath(from: stroke.pathData)
        var transform = scaleTransform(to: canvasSize)
        let scaledPath = cgPath.copy(using: &transform) ?? cgPath

        let layer = CAShapeLayer()
        layer.path = scaledPath
        layer.strokeColor = appearance.strokeColor
            .withAlphaComponent(appearance.alpha).cgColor
        layer.fillColor = nil
        layer.lineWidth = appearance.lineWidth
        layer.lineCap = appearance.lineCap
        layer.lineJoin = appearance.lineJoin
        return layer
    }

    /// Adds a strokeEnd animation (0 -> 1) to a layer with optional delayed start.
    @MainActor
    static func addDrawingAnimation(
        to layer: CAShapeLayer,
        duration: CFTimeInterval = 0.5,
        beginTime: CFTimeInterval = 0
    ) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = duration
        if beginTime > 0 {
            animation.beginTime = CACurrentMediaTime() + beginTime
        }
        animation.fillMode = .backwards
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "strokeEndAnimation")
    }
}
