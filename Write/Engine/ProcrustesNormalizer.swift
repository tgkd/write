import CoreGraphics

/// Procrustes normalization: translate centroid to origin, scale to unit size, find optimal rotation.
enum ProcrustesNormalizer {

    struct NormalizedCurve {
        let points: [CGPoint]
        let centroid: CGPoint
        let scale: CGFloat
        let rotation: CGFloat
    }

    /// Computes the centroid (geometric center) of a point sequence.
    static func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for p in points {
            sumX += p.x
            sumY += p.y
        }
        let n = CGFloat(points.count)
        return CGPoint(x: sumX / n, y: sumY / n)
    }

    /// Translates points so their centroid is at the origin.
    static func translateToOrigin(_ points: [CGPoint]) -> [CGPoint] {
        let c = centroid(of: points)
        return points.map { CGPoint(x: $0.x - c.x, y: $0.y - c.y) }
    }

    /// Computes the RMS (root-mean-square) size of a centered point set.
    static func rmsSize(of points: [CGPoint]) -> CGFloat {
        guard !points.isEmpty else { return 0 }
        var sumSq: CGFloat = 0
        for p in points {
            sumSq += p.x * p.x + p.y * p.y
        }
        return sqrt(sumSq / CGFloat(points.count))
    }

    /// Scales points so their RMS size is 1.
    static func scaleToUnit(_ points: [CGPoint]) -> (points: [CGPoint], scale: CGFloat) {
        let size = rmsSize(of: points)
        guard size > 0 else { return (points, 1) }
        let scaled = points.map { CGPoint(x: $0.x / size, y: $0.y / size) }
        return (scaled, size)
    }

    /// Rotates points by the given angle (radians) around the origin.
    static func rotate(_ points: [CGPoint], by angle: CGFloat) -> [CGPoint] {
        let cosA = cos(angle)
        let sinA = sin(angle)
        return points.map {
            CGPoint(
                x: $0.x * cosA - $0.y * sinA,
                y: $0.x * sinA + $0.y * cosA
            )
        }
    }

    /// Finds the optimal rotation angle that minimizes the sum of squared distances
    /// between two centered, unit-scaled point sequences, using the analytical SVD solution.
    static func optimalRotation(from source: [CGPoint], to target: [CGPoint]) -> CGFloat {
        guard source.count == target.count, !source.isEmpty else { return 0 }

        var sumSin: CGFloat = 0
        var sumCos: CGFloat = 0

        for i in 0..<source.count {
            sumCos += source[i].x * target[i].x + source[i].y * target[i].y
            sumSin += source[i].x * target[i].y - source[i].y * target[i].x
        }

        return atan2(sumSin, sumCos)
    }

    /// Full Procrustes normalization: center, scale, then optimally rotate source to match target.
    /// When `applyRotation` is false, only translation and uniform scaling are applied,
    /// preserving the original curve direction for Frechet distance comparison.
    static func normalize(
        source: [CGPoint],
        target: [CGPoint],
        applyRotation: Bool = true
    ) -> (source: NormalizedCurve, target: NormalizedCurve) {
        let sourceCentroid = centroid(of: source)
        let targetCentroid = centroid(of: target)

        let sourceCentered = translateToOrigin(source)
        let targetCentered = translateToOrigin(target)

        let (sourceScaled, sourceSize) = scaleToUnit(sourceCentered)
        let (targetScaled, targetSize) = scaleToUnit(targetCentered)

        let angle: CGFloat
        let sourceAligned: [CGPoint]
        if applyRotation {
            angle = optimalRotation(from: sourceScaled, to: targetScaled)
            sourceAligned = rotate(sourceScaled, by: angle)
        } else {
            angle = 0
            sourceAligned = sourceScaled
        }

        return (
            source: NormalizedCurve(
                points: sourceAligned,
                centroid: sourceCentroid,
                scale: sourceSize,
                rotation: angle
            ),
            target: NormalizedCurve(
                points: targetScaled,
                centroid: targetCentroid,
                scale: targetSize,
                rotation: 0
            )
        )
    }

    /// Computes the Procrustes distance (sum of squared distances after alignment).
    static func procrustesDistance(source: [CGPoint], target: [CGPoint]) -> CGFloat {
        let (normSource, normTarget) = normalize(source: source, target: target)
        var sumSq: CGFloat = 0
        for i in 0..<normSource.points.count {
            let dx = normSource.points[i].x - normTarget.points[i].x
            let dy = normSource.points[i].y - normTarget.points[i].y
            sumSq += dx * dx + dy * dy
        }
        return sqrt(sumSq / CGFloat(normSource.points.count))
    }
}
