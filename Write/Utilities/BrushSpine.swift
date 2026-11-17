import CoreGraphics

struct BrushSpine {
    var points: [CGPoint] = []
    var radii: [CGFloat] = []
    var arcs: [CGFloat] = []

    var count: Int { points.count }

    var length: CGFloat { arcs.last ?? 0 }

    mutating func append(_ other: BrushSpine, range: Range<Int>) {
        points += other.points[range]
        radii += other.radii[range]
        arcs += other.arcs[range]
    }

    static func build(
        controls: [BrushStroke.Sample],
        from first: Int,
        startArc: CGFloat,
        config: BrushStroke.Config,
        taperStart: Bool
    ) -> BrushSpine {
        let count = controls.count
        guard first < count else { return BrushSpine() }
        let contextStart = max(0, first - config.centerlineRadius - 3)
        let centerline = BrushStroke.smoothCenterline(
            Array(controls[contextStart...]),
            firstIndex: contextStart,
            totalCount: count,
            config: config
        )
        let windowStart = max(0, first - 2)
        let subdivisions = config.smoothingSubdivisions
        let spline = CatmullRomSpline.interpolate(
            points: Array(centerline[(windowStart - contextStart)...]),
            alpha: config.smoothingAlpha,
            subdivisions: subdivisions
        )
        let points = Array(spline.dropFirst((first - windowStart) * subdivisions))
        let controlWidths = BrushStroke.bodyWidths(of: controls, in: first..<count, config: config)

        var spine = BrushSpine()
        spine.points = points
        spine.radii.reserveCapacity(points.count)
        spine.arcs.reserveCapacity(points.count)
        var arc = startArc
        for (k, point) in points.enumerated() {
            if k > 0 {
                let previous = points[k - 1]
                arc += hypot(point.x - previous.x, point.y - previous.y)
            }
            spine.arcs.append(arc)
            let segment = k / subdivisions
            let t = CGFloat(k % subdivisions) / CGFloat(subdivisions)
            let width = segment + 1 < controlWidths.count
                ? controlWidths[segment] * (1 - t) + controlWidths[segment + 1] * t
                : controlWidths[min(segment, controlWidths.count - 1)]
            spine.radii.append(width)
        }
        let length = arc
        for k in spine.radii.indices {
            let factor = BrushStroke.taperFactor(
                arc: spine.arcs[k], length: length, config: config, taperStart: taperStart
            )
            spine.radii[k] *= factor / 2
        }
        return spine
    }
}
