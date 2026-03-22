import Foundation
import CoreGraphics

/// One Euro Filter for smoothing stylus input while preserving fast stroke responsiveness.
/// At low speed: heavy smoothing eliminates jitter/tremor.
/// At high speed: light smoothing preserves responsiveness and reduces lag.
struct OneEuroFilter {

    var minCutoff: CGFloat
    var beta: CGFloat
    var dCutoff: CGFloat

    private var xFilter = LowPass()
    private var dxFilter = LowPass()
    private var yFilter = LowPass()
    private var dyFilter = LowPass()
    private var lastTimestamp: TimeInterval?

    init(minCutoff: CGFloat = 1.5, beta: CGFloat = 0.5, dCutoff: CGFloat = 10.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    mutating func reset() {
        xFilter = LowPass()
        dxFilter = LowPass()
        yFilter = LowPass()
        dyFilter = LowPass()
        lastTimestamp = nil
    }

    mutating func filter(point: CGPoint, timestamp: TimeInterval) -> CGPoint {
        guard let prevTimestamp = lastTimestamp else {
            lastTimestamp = timestamp
            xFilter.seed(point.x)
            yFilter.seed(point.y)
            dxFilter.seed(0)
            dyFilter.seed(0)
            return point
        }

        let dt = CGFloat(max(timestamp - prevTimestamp, 0.001))
        lastTimestamp = timestamp

        let dx = (point.x - xFilter.value) / dt
        let dy = (point.y - yFilter.value) / dt

        let alphaD = Self.alpha(dt: dt, cutoff: dCutoff)
        let smoothDX = dxFilter.apply(dx, alpha: alphaD)
        let smoothDY = dyFilter.apply(dy, alpha: alphaD)

        let speed = hypot(smoothDX, smoothDY)
        let cutoff = minCutoff + beta * speed
        let alphaPos = Self.alpha(dt: dt, cutoff: cutoff)

        return CGPoint(
            x: xFilter.apply(point.x, alpha: alphaPos),
            y: yFilter.apply(point.y, alpha: alphaPos)
        )
    }

    private static func alpha(dt: CGFloat, cutoff: CGFloat) -> CGFloat {
        let tau = 1.0 / (2.0 * .pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }
}

private struct LowPass {
    private(set) var value: CGFloat = 0

    mutating func seed(_ v: CGFloat) {
        value = v
    }

    @discardableResult
    mutating func apply(_ raw: CGFloat, alpha: CGFloat) -> CGFloat {
        value += alpha * (raw - value)
        return value
    }
}
