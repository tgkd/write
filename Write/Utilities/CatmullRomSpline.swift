import CoreGraphics

/// Centripetal Catmull-Rom spline interpolation for smoothing touch input curves.
enum CatmullRomSpline {

    /// Interpolates a sequence of points using centripetal Catmull-Rom splines.
    /// - Parameters:
    ///   - points: The control points to interpolate through. Needs at least 2 points.
    ///   - alpha: Parameterization exponent. 0.5 for centripetal (default), 0.0 for uniform, 1.0 for chordal.
    ///   - subdivisions: Number of interpolated segments between each pair of control points.
    /// - Returns: Smoothed point array that passes through all original control points.
    static func interpolate(
        points: [CGPoint],
        alpha: CGFloat = 0.5,
        subdivisions: Int = 8
    ) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        if points.count == 2 {
            return linearInterpolation(p0: points[0], p1: points[1], subdivisions: subdivisions)
        }

        var result: [CGPoint] = []

        for i in 0..<(points.count - 1) {
            let p0 = i > 0 ? points[i - 1] : mirrorPoint(points[1], around: points[0])
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : mirrorPoint(points[points.count - 2], around: points[points.count - 1])

            let segment = interpolateSegment(p0: p0, p1: p1, p2: p2, p3: p3, alpha: alpha, subdivisions: subdivisions)

            if i == 0 {
                result.append(contentsOf: segment)
            } else {
                result.append(contentsOf: segment.dropFirst())
            }
        }

        return result
    }

    /// Creates a CGPath from interpolated points.
    static func createPath(from points: [CGPoint], alpha: CGFloat = 0.5, subdivisions: Int = 8) -> CGPath {
        let smoothed = interpolate(points: points, alpha: alpha, subdivisions: subdivisions)
        let path = CGMutablePath()

        guard let first = smoothed.first else { return path }
        path.move(to: first)
        for point in smoothed.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }

    // MARK: - Private

    private static func interpolateSegment(
        p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint,
        alpha: CGFloat, subdivisions: Int
    ) -> [CGPoint] {
        let t0: CGFloat = 0
        let t1 = knotValue(t: t0, p0: p0, p1: p1, alpha: alpha)
        let t2 = knotValue(t: t1, p0: p1, p1: p2, alpha: alpha)
        let t3 = knotValue(t: t2, p0: p2, p1: p3, alpha: alpha)

        var segment: [CGPoint] = []
        for j in 0...subdivisions {
            let t = t1 + (t2 - t1) * CGFloat(j) / CGFloat(subdivisions)

            let a1 = lerp(p0, p1, t0: t0, t1: t1, t: t)
            let a2 = lerp(p1, p2, t0: t1, t1: t2, t: t)
            let a3 = lerp(p2, p3, t0: t2, t1: t3, t: t)

            let b1 = lerp(a1, a2, t0: t0, t1: t2, t: t)
            let b2 = lerp(a2, a3, t0: t1, t1: t3, t: t)

            let c = lerp(b1, b2, t0: t0, t1: t3, t: t)
            segment.append(c)
        }

        return segment
    }

    private static func knotValue(t: CGFloat, p0: CGPoint, p1: CGPoint, alpha: CGFloat) -> CGFloat {
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        let distSquared = dx * dx + dy * dy
        return t + pow(distSquared, alpha / 2.0)
    }

    private static func lerp(_ p0: CGPoint, _ p1: CGPoint, t0: CGFloat, t1: CGFloat, t: CGFloat) -> CGPoint {
        guard t1 != t0 else { return p0 }
        let f = (t - t0) / (t1 - t0)
        return CGPoint(
            x: p0.x + (p1.x - p0.x) * f,
            y: p0.y + (p1.y - p0.y) * f
        )
    }

    private static func mirrorPoint(_ point: CGPoint, around pivot: CGPoint) -> CGPoint {
        CGPoint(
            x: 2 * pivot.x - point.x,
            y: 2 * pivot.y - point.y
        )
    }

    private static func linearInterpolation(p0: CGPoint, p1: CGPoint, subdivisions: Int) -> [CGPoint] {
        var result: [CGPoint] = []
        for i in 0...subdivisions {
            let t = CGFloat(i) / CGFloat(subdivisions)
            result.append(CGPoint(
                x: p0.x + (p1.x - p0.x) * t,
                y: p0.y + (p1.y - p0.y) * t
            ))
        }
        return result
    }
}
