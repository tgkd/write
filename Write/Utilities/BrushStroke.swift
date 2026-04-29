import Foundation
import CoreGraphics

/// Builds variable-width filled paths that simulate calligraphy brush strokes.
/// Width varies inversely with drawing speed: slow = thick, fast = thin.
enum BrushStroke {

    struct Sample {
        let point: CGPoint
        let timestamp: TimeInterval
        let force: CGFloat?
        /// Pencil altitude in radians. π/2 ≈ perpendicular to surface, near 0 ≈ flat against surface.
        let altitude: CGFloat?

        init(point: CGPoint, timestamp: TimeInterval, force: CGFloat? = nil, altitude: CGFloat? = nil) {
            self.point = point
            self.timestamp = timestamp
            self.force = force
            self.altitude = altitude
        }
    }

    struct Config {
        var minWidth: CGFloat = 1.5
        var maxWidth: CGFloat = 8.0
        var taperFraction: CGFloat = 0.15
        var speedSmoothing: CGFloat = 0.85
        var smoothingAlpha: CGFloat = 0.5
        var smoothingSubdivisions: Int = 8
        var pressureSensitivity: PressureSensitivity = .off
        var tiltSensitivity: TiltSensitivity = .off
        var filterMinCutoff: CGFloat = 1.5
        var filterBeta: CGFloat = 0.5
    }

    /// Creates a filled CGPath with variable width from touch samples.
    static func createPath(from samples: [Sample], config: Config = Config()) -> CGPath {
        let filtered = filterByDistance(samples)
        let points = filtered.map(\.point)
        guard points.count >= 2 else {
            return dotPath(at: points.first ?? .zero, radius: config.maxWidth / 2)
        }

        let rawWidths = computeWidths(from: filtered, config: config)

        let smoothedPoints = CatmullRomSpline.interpolate(
            points: points,
            alpha: config.smoothingAlpha,
            subdivisions: config.smoothingSubdivisions
        )

        let smoothedWidths = interpolateWidths(
            rawWidths: rawWidths,
            segmentCount: points.count - 1,
            subdivisions: config.smoothingSubdivisions,
            targetCount: smoothedPoints.count
        )

        return buildRibbon(points: smoothedPoints, widths: smoothedWidths)
    }

    // MARK: - Private

    private static func filterByDistance(_ samples: [Sample], minDistance: CGFloat = 4.0) -> [Sample] {
        guard samples.count >= 2 else { return samples }
        var result = [samples[0]]
        let minDistSq = minDistance * minDistance
        for i in 1..<(samples.count - 1) {
            let prev = result.last!.point
            let cur = samples[i].point
            let dx = cur.x - prev.x
            let dy = cur.y - prev.y
            if dx * dx + dy * dy >= minDistSq {
                result.append(samples[i])
            }
        }
        result.append(samples.last!)
        return result
    }

    private static func computeWidths(from samples: [Sample], config: Config) -> [CGFloat] {
        let count = samples.count
        guard count >= 2 else { return [config.maxWidth] }

        var speeds = [CGFloat](repeating: 0, count: count)
        for i in 1..<count {
            let dt = samples[i].timestamp - samples[i - 1].timestamp
            guard dt > 0.0001 else {
                speeds[i] = speeds[i - 1]
                continue
            }
            let dx = samples[i].point.x - samples[i - 1].point.x
            let dy = samples[i].point.y - samples[i - 1].point.y
            speeds[i] = hypot(dx, dy) / CGFloat(dt)
        }
        speeds[0] = speeds[1]

        // Bidirectional exponential moving average
        let alpha = config.speedSmoothing
        var forward = speeds
        for i in 1..<count {
            forward[i] = forward[i - 1] * alpha + forward[i] * (1 - alpha)
        }
        var backward = speeds
        for i in stride(from: count - 2, through: 0, by: -1) {
            backward[i] = backward[i + 1] * alpha + backward[i] * (1 - alpha)
        }
        for i in 0..<count {
            speeds[i] = (forward[i] + backward[i]) / 2
        }

        let slowSpeed: CGFloat = 100
        let fastSpeed: CGFloat = 1500
        let pressureBlend = config.pressureSensitivity.blendFactor
        let tiltBlend = config.tiltSensitivity.blendFactor
        var widths: [CGFloat] = samples.enumerated().map { i, sample in
            let speedT = min(1, max(0, (speeds[i] - slowSpeed) / (fastSpeed - slowSpeed)))
            var width = config.maxWidth - speedT * (config.maxWidth - config.minWidth)

            if pressureBlend > 0, let force = sample.force, force > 0 {
                let maxForce: CGFloat = 4.0
                let forceT = min(1, force / maxForce)
                let forceWidth = config.minWidth + forceT * (config.maxWidth - config.minWidth)
                width = width * (1 - pressureBlend) + forceWidth * pressureBlend
            }

            if tiltBlend > 0, let altitude = sample.altitude {
                let tiltT = max(0, min(1, 1 - altitude / (.pi / 2)))
                let tiltWidth = config.minWidth + tiltT * (config.maxWidth - config.minWidth)
                width = width * (1 - tiltBlend) + tiltWidth * tiltBlend
            }

            return width
        }

        // Taper at start and end
        let taperCount = max(1, Int(CGFloat(count) * config.taperFraction))
        for i in 0..<min(taperCount, count) {
            let t = CGFloat(i + 1) / CGFloat(taperCount + 1)
            widths[i] *= t
        }
        for i in 0..<min(taperCount, count) {
            let idx = count - 1 - i
            let t = CGFloat(i + 1) / CGFloat(taperCount + 1)
            widths[idx] *= t
        }

        return widths
    }

    private static func interpolateWidths(
        rawWidths: [CGFloat],
        segmentCount: Int,
        subdivisions: Int,
        targetCount: Int
    ) -> [CGFloat] {
        var result: [CGFloat] = []
        for i in 0..<segmentCount {
            for j in 0...subdivisions {
                if i > 0 && j == 0 { continue }
                let t = CGFloat(j) / CGFloat(subdivisions)
                result.append(rawWidths[i] * (1 - t) + rawWidths[i + 1] * t)
            }
        }
        while result.count < targetCount { result.append(result.last ?? 1) }
        if result.count > targetCount { result.removeLast(result.count - targetCount) }
        return result
    }

    private static func buildRibbon(points: [CGPoint], widths: [CGFloat]) -> CGPath {
        guard points.count >= 2 else {
            return dotPath(at: points.first ?? .zero, radius: (widths.first ?? 4) / 2)
        }

        var leftEdge: [CGPoint] = []
        var rightEdge: [CGPoint] = []
        var prevNx: CGFloat = 1
        var prevNy: CGFloat = 0

        let spans = [1, 3, 5]
        let spanWeights: [CGFloat] = [0.5, 0.3, 0.2]

        for i in 0..<points.count {
            var dx: CGFloat = 0
            var dy: CGFloat = 0
            for (span, weight) in zip(spans, spanWeights) {
                let p = max(0, i - span)
                let n = min(points.count - 1, i + span)
                dx += (points[n].x - points[p].x) * weight
                dy += (points[n].y - points[p].y) * weight
            }
            let len = hypot(dx, dy)

            let nx: CGFloat
            let ny: CGFloat
            if len > 0.001 {
                nx = -dy / len
                ny = dx / len
                prevNx = nx
                prevNy = ny
            } else {
                nx = prevNx
                ny = prevNy
            }

            let hw = widths[i] / 2
            leftEdge.append(CGPoint(x: points[i].x + nx * hw, y: points[i].y + ny * hw))
            rightEdge.append(CGPoint(x: points[i].x - nx * hw, y: points[i].y - ny * hw))
        }

        let path = CGMutablePath()
        path.move(to: leftEdge[0])
        for p in leftEdge.dropFirst() { path.addLine(to: p) }
        for p in rightEdge.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }

    private static func dotPath(at center: CGPoint, radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ), transform: nil)
    }
}
