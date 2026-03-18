import CoreGraphics

/// Samples equally-spaced points along a CGPath or point array.
enum PointSampler {

    /// Default number of sample points.
    static let defaultSampleCount = 50

    /// Samples N equally-spaced points along a polyline defined by a point array.
    static func sample(points: [CGPoint], count: Int = defaultSampleCount) -> [CGPoint] {
        guard points.count >= 2, count >= 2 else { return points }

        let lengths = cumulativeLengths(for: points)
        let totalLength = lengths.last ?? 0
        guard totalLength > 0 else { return [points[0]] }
        var result: [CGPoint] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let targetLength = totalLength * CGFloat(i) / CGFloat(count - 1)
            let point = pointAtLength(targetLength, points: points, cumulativeLengths: lengths)
            result.append(point)
        }

        return result
    }

    /// Samples N equally-spaced points along a CGPath by first flattening it to line segments.
    static func sample(path: CGPath, count: Int = defaultSampleCount) -> [CGPoint] {
        let points = flattenPath(path)
        return sample(points: points, count: count)
    }

    /// Flattens a CGPath into a polyline (sequence of points from line segments).
    static func flattenPath(_ path: CGPath) -> [CGPoint] {
        var points: [CGPoint] = []
        var currentPoint = CGPoint.zero

        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                currentPoint = element.pointee.points[0]
                points.append(currentPoint)
            case .addLineToPoint:
                currentPoint = element.pointee.points[0]
                points.append(currentPoint)
            case .addQuadCurveToPoint:
                let cp = element.pointee.points[0]
                let end = element.pointee.points[1]
                let subdivisions = 8
                for j in 1...subdivisions {
                    let t = CGFloat(j) / CGFloat(subdivisions)
                    let oneMinusT = 1 - t
                    let x = oneMinusT * oneMinusT * currentPoint.x
                        + 2 * oneMinusT * t * cp.x
                        + t * t * end.x
                    let y = oneMinusT * oneMinusT * currentPoint.y
                        + 2 * oneMinusT * t * cp.y
                        + t * t * end.y
                    points.append(CGPoint(x: x, y: y))
                }
                currentPoint = end
            case .addCurveToPoint:
                let cp1 = element.pointee.points[0]
                let cp2 = element.pointee.points[1]
                let end = element.pointee.points[2]
                let subdivisions = 8
                for j in 1...subdivisions {
                    let t = CGFloat(j) / CGFloat(subdivisions)
                    let oneMinusT = 1 - t
                    let x = oneMinusT * oneMinusT * oneMinusT * currentPoint.x
                        + 3 * oneMinusT * oneMinusT * t * cp1.x
                        + 3 * oneMinusT * t * t * cp2.x
                        + t * t * t * end.x
                    let y = oneMinusT * oneMinusT * oneMinusT * currentPoint.y
                        + 3 * oneMinusT * oneMinusT * t * cp1.y
                        + 3 * oneMinusT * t * t * cp2.y
                        + t * t * t * end.y
                    points.append(CGPoint(x: x, y: y))
                }
                currentPoint = end
            case .closeSubpath:
                if let first = points.first, currentPoint != first {
                    points.append(first)
                    currentPoint = first
                }
            @unknown default:
                break
            }
        }

        return points
    }

    // MARK: - Private

    private static func cumulativeLengths(for points: [CGPoint]) -> [CGFloat] {
        var lengths: [CGFloat] = [0]
        lengths.reserveCapacity(points.count)
        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x
            let dy = points[i].y - points[i - 1].y
            let segLength = sqrt(dx * dx + dy * dy)
            lengths.append(lengths[i - 1] + segLength)
        }
        return lengths
    }

    private static func pointAtLength(
        _ targetLength: CGFloat,
        points: [CGPoint],
        cumulativeLengths: [CGFloat]
    ) -> CGPoint {
        if targetLength <= 0 { return points[0] }
        if targetLength >= cumulativeLengths.last! { return points.last! }

        var lo = 0
        var hi = cumulativeLengths.count - 1
        while lo < hi - 1 {
            let mid = (lo + hi) / 2
            if cumulativeLengths[mid] <= targetLength {
                lo = mid
            } else {
                hi = mid
            }
        }

        let segStart = cumulativeLengths[lo]
        let segEnd = cumulativeLengths[hi]
        let segLength = segEnd - segStart
        guard segLength > 0 else { return points[lo] }

        let t = (targetLength - segStart) / segLength
        return CGPoint(
            x: points[lo].x + (points[hi].x - points[lo].x) * t,
            y: points[lo].y + (points[hi].y - points[lo].y) * t
        )
    }
}
