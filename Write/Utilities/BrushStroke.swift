import Foundation
import CoreGraphics

/// Builds variable-width filled paths that simulate calligraphy brush strokes.
/// Width varies inversely with drawing speed: slow = thick, fast = thin.
enum BrushStroke {

    struct Sample {
        let point: CGPoint
        let timestamp: TimeInterval
        /// Pencil force normalized to 0…1 of the device's maximumPossibleForce.
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

    enum WidthModel: Sendable {
        case speed
        case finger
    }

    struct Config {
        var widthModel: WidthModel = .speed
        var smoothing: SmoothingStrength = .medium
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
        var centerlineRadius: Int = 2
        var centerlineMaxShift: CGFloat = 1.25
    }

    /// Creates a filled CGPath with variable width from touch samples.
    static func createPath(from samples: [Sample], config: Config = Config()) -> CGPath {
        let filtered = filterByDistance(samples)
        let centerline = smoothCenterline(filtered, firstIndex: 0, totalCount: filtered.count, config: config)
        return path(fromFiltered: filtered, centerline: centerline, config: config, taperStart: true, taperEnd: true)
    }

    static func smoothCenterline(
        _ samples: [Sample],
        firstIndex: Int,
        totalCount: Int,
        config: Config
    ) -> [CGPoint] {
        let points = samples.map(\.point)
        let radius = config.centerlineRadius
        guard radius > 0, points.count > 2 else { return points }

        let isCorner: [Bool] = points.indices.map { j in
            guard j > 0, j < points.count - 1 else { return false }
            return turnCosine(points[j - 1], points[j], points[j + 1]) < cornerCosine
        }

        let maxShiftSq = config.centerlineMaxShift * config.centerlineMaxShift
        var result = points
        for j in points.indices {
            let global = firstIndex + j
            var r = min(radius, global, totalCount - 1 - global, j, points.count - 1 - j)
            while r > 0, (j - r...j + r).contains(where: { isCorner[$0] }) {
                r -= 1
            }
            if r <= 0 { continue }

            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            var weightSum: CGFloat = 0
            for k in -r...r {
                let weight = CGFloat(r + 1 - abs(k))
                sumX += points[j + k].x * weight
                sumY += points[j + k].y * weight
                weightSum += weight
            }
            var dx = sumX / weightSum - points[j].x
            var dy = sumY / weightSum - points[j].y
            let shiftSq = dx * dx + dy * dy
            if shiftSq > maxShiftSq {
                let scale = config.centerlineMaxShift / sqrt(shiftSq)
                dx *= scale
                dy *= scale
            }
            result[j] = CGPoint(x: points[j].x + dx, y: points[j].y + dy)
        }
        return result
    }

    /// Builds the ribbon for samples that are ALREADY distance-filtered.
    /// Taper flags let the incremental renderer build interior segments that
    /// must not thin out at their cut points.
    static func path(
        fromFiltered filtered: [Sample],
        centerline: [CGPoint]? = nil,
        config: Config,
        taperStart: Bool,
        taperEnd: Bool,
        arcOffset: CGFloat = 0
    ) -> CGPath {
        let points = centerline ?? filtered.map(\.point)
        guard points.count >= 2 else {
            return dotPath(at: points.first ?? .zero, radius: config.maxWidth / 2)
        }

        let rawWidths = computeWidths(
            from: filtered, config: config, taperStart: taperStart, taperEnd: taperEnd
        )

        let smoothedPoints = CatmullRomSpline.interpolate(
            points: points,
            alpha: config.smoothingAlpha,
            subdivisions: config.smoothingSubdivisions
        )

        var smoothedWidths = interpolateWidths(
            rawWidths: rawWidths,
            segmentCount: points.count - 1,
            subdivisions: config.smoothingSubdivisions,
            targetCount: smoothedPoints.count
        )

        if config.widthModel == .finger {
            applyFingerProfile(
                to: &smoothedWidths,
                points: smoothedPoints,
                config: config,
                taperStart: taperStart,
                taperEnd: taperEnd,
                arcOffset: arcOffset
            )
        }

        return buildRibbon(points: smoothedPoints, widths: smoothedWidths, capStart: taperStart, capEnd: taperEnd)
    }

    /// Incrementally renders an in-progress stroke in O(tail) per update
    /// instead of O(stroke) — ribbon geometry older than `tailWindow` filtered
    /// samples is frozen into a prefix path and only the tail is rebuilt.
    ///
    /// The live path is a close approximation (frozen chunks compute widths
    /// from local context, and refinements to frozen samples are not
    /// re-rendered); callers must build the COMMITTED stroke with
    /// `createPath(from:config:)` so final ink is identical to a full build.
    /// Frozen chunks overlap their neighbors by 2 samples; the overlapping
    /// fills only hide seams for opaque single-color ink.
    ///
    /// Not value-semantic (the frozen prefix is a shared CGMutablePath) —
    /// intended for a single owner per stroke.
    struct LiveRenderer {

        /// Filtered samples covered by both the end taper and the ribbon's
        /// normal/width smoothing windows; geometry older than this cannot
        /// visibly change as new samples arrive.
        static let tailWindow = 16
        private static let overlap = 2
        private static let minDistanceSq: CGFloat = 16  // matches filterByDistance's 4pt

        private let config: Config
        private var kept: [Sample] = []
        private var keptArc: [CGFloat] = []
        private var keptRawIndices: [Int] = []
        private var provisional: Sample?
        private var provisionalRawIndex: Int?
        private var rawCount = 0
        private var frozenPath = CGMutablePath()
        private var frozenKeptCount = 0

        init(config: Config) {
            self.config = config
        }

        /// Appends the next raw sample, applying the same incremental distance
        /// filter as `filterByDistance` (last raw sample always rides along).
        mutating func append(_ sample: Sample) {
            if let prov = provisional, let provIdx = provisionalRawIndex {
                let farEnough = kept.last.map {
                    let dx = prov.point.x - $0.point.x
                    let dy = prov.point.y - $0.point.y
                    return dx * dx + dy * dy >= Self.minDistanceSq
                } ?? true
                if farEnough {
                    let step = kept.last.map { hypot(prov.point.x - $0.point.x, prov.point.y - $0.point.y) } ?? 0
                    keptArc.append((keptArc.last ?? 0) + step)
                    kept.append(prov)
                    keptRawIndices.append(provIdx)
                }
            }
            provisional = sample
            provisionalRawIndex = rawCount
            rawCount += 1
            freezeIfNeeded()
        }

        /// Patches force/altitude of a raw sample if it can still affect the
        /// live path. Refinements landing in frozen geometry are ignored here;
        /// the committed rebuild picks them up.
        mutating func refine(rawIndex: Int, force: CGFloat?, altitude: CGFloat?) {
            if provisionalRawIndex == rawIndex, let p = provisional {
                provisional = Sample(point: p.point, timestamp: p.timestamp, force: force, altitude: altitude)
                return
            }
            var i = keptRawIndices.count - 1
            while i >= frozenKeptCount {
                if keptRawIndices[i] == rawIndex {
                    let s = kept[i]
                    kept[i] = Sample(point: s.point, timestamp: s.timestamp, force: force, altitude: altitude)
                    return
                }
                i -= 1
            }
        }

        /// The full live path: frozen prefix plus a freshly built tail.
        func currentPath() -> CGPath {
            let start = max(0, frozenKeptCount - Self.overlap)
            let contextStart = max(0, start - contextLength)
            var window = Array(kept[contextStart...])
            if let prov = provisional { window.append(prov) }
            let smoothed = BrushStroke.smoothCenterline(
                window, firstIndex: contextStart, totalCount: totalCount, config: config
            )
            let offset = start - contextStart
            let tailPath = BrushStroke.path(
                fromFiltered: Array(window.dropFirst(offset)),
                centerline: Array(smoothed.dropFirst(offset)),
                config: config, taperStart: start == 0, taperEnd: true,
                arcOffset: arcLength(at: start)
            )
            if frozenPath.isEmpty { return tailPath }
            let combined = CGMutablePath()
            combined.addPath(frozenPath)
            combined.addPath(tailPath)
            return combined
        }

        /// A short stub from the last committed samples plus the predictions —
        /// the predicted layer no longer redraws the whole stroke.
        func predictedPath(with predictedSamples: [Sample]) -> CGPath {
            let stubLength = min(3, kept.count) + (provisional == nil ? 0 : 1)
            let contextStart = max(0, kept.count - 3 - contextLength)
            var window = Array(kept[contextStart...])
            if let prov = provisional { window.append(prov) }
            let smoothed = BrushStroke.smoothCenterline(
                window, firstIndex: contextStart, totalCount: totalCount, config: config
            )
            return BrushStroke.path(
                fromFiltered: Array(window.suffix(stubLength)) + predictedSamples,
                centerline: Array(smoothed.suffix(stubLength)) + predictedSamples.map(\.point),
                config: config,
                taperStart: false, taperEnd: true,
                arcOffset: arcLength(at: kept.count - min(3, kept.count))
            )
        }

        private func arcLength(at keptIndex: Int) -> CGFloat {
            guard keptArc.indices.contains(keptIndex) else {
                return keptArc.last ?? 0
            }
            return keptArc[keptIndex]
        }

        private var contextLength: Int {
            config.centerlineRadius + 1
        }

        private var totalCount: Int {
            kept.count + (provisional == nil ? 0 : 1)
        }

        private mutating func freezeIfNeeded() {
            while kept.count - frozenKeptCount > 2 * Self.tailWindow {
                let chunkEnd = frozenKeptCount + Self.tailWindow
                let start = max(0, frozenKeptCount - Self.overlap)
                let end = min(kept.count, chunkEnd + Self.overlap)
                let contextStart = max(0, start - contextLength)
                let contextEnd = min(kept.count, end + contextLength)
                let smoothed = BrushStroke.smoothCenterline(
                    Array(kept[contextStart..<contextEnd]),
                    firstIndex: contextStart, totalCount: totalCount, config: config
                )
                let chunkRange = (start - contextStart)..<(end - contextStart)
                let chunk = BrushStroke.path(
                    fromFiltered: Array(kept[start..<end]),
                    centerline: Array(smoothed[chunkRange]),
                    config: config,
                    taperStart: start == 0, taperEnd: false,
                    arcOffset: arcLength(at: start)
                )
                frozenPath.addPath(chunk)
                frozenKeptCount = chunkEnd
            }
        }
    }

    // MARK: - Private

    /// Maximum samples tapered at each end, independent of total stroke length, so the
    /// start/end of a stroke stops re-tapering (visibly thinning) as the stroke grows.
    private static let maxTaperSamples = 6

    /// Minimum fraction of width retained at the very tip of a taper, so stroke ends
    /// round off instead of collapsing to a sharp needle point.
    private static let taperTipFloor: CGFloat = 0.4

    /// Response curve for normalized force. Average handwriting force is only
    /// ~0.24 of maximumPossibleForce; a square root lifts it to mid-width so
    /// the pressure setting is perceptible at typical writing pressure.
    private static let forceGamma: CGFloat = 0.5

    private static let cornerCosine: CGFloat = cos(.pi / 4)

    private enum Finger {
        static let slowSpeed: CGFloat = 150
        static let fastSpeed: CGFloat = 1200
        static let speedThinning: CGFloat = 0.2
        static let tipFloor: CGFloat = 0.15
        static let pressInWidths: CGFloat = 1.25
        static let pressInMaxFraction: CGFloat = 0.25
        static let tipWidths: CGFloat = 2
        static let tipMaxFraction: CGFloat = 0.3
        static let thinningWidths: CGFloat = 25
        static let endWidth: CGFloat = 0.75
    }

    private static let capSegments = 8

    private static func applyFingerProfile(
        to widths: inout [CGFloat],
        points: [CGPoint],
        config: Config,
        taperStart: Bool,
        taperEnd: Bool,
        arcOffset: CGFloat
    ) {
        guard widths.count == points.count, let first = points.first else {
            return
        }
        var arc: [CGFloat] = [0]
        arc.reserveCapacity(points.count)
        var previous = first
        for point in points.dropFirst() {
            arc.append(arc[arc.count - 1] + hypot(point.x - previous.x, point.y - previous.y))
            previous = point
        }
        let total = arc[arc.count - 1]
        let pressIn = min(config.maxWidth * Finger.pressInWidths, total * Finger.pressInMaxFraction)
        let tip = min(config.maxWidth * Finger.tipWidths, total * Finger.tipMaxFraction)
        let thinningLength = config.maxWidth * Finger.thinningWidths

        for i in widths.indices {
            let fromStart = arc[i]
            let toEnd = total - fromStart
            let progress = min(1, (arcOffset + fromStart) / thinningLength)
            let eased = progress * progress * (3 - 2 * progress)
            var factor = 1 - (1 - Finger.endWidth) * eased
            if taperStart, pressIn > 0, fromStart < pressIn {
                factor *= Finger.tipFloor + (1 - Finger.tipFloor) * sqrt(fromStart / pressIn)
            }
            if taperEnd, tip > 0, toEnd < tip {
                let t = toEnd / tip
                factor *= Finger.tipFloor + (1 - Finger.tipFloor) * t * (2 - t)
            }
            widths[i] *= factor
        }
    }

    private static func turnCosine(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        let ux = b.x - a.x
        let uy = b.y - a.y
        let vx = c.x - b.x
        let vy = c.y - b.y
        let lengths = hypot(ux, uy) * hypot(vx, vy)
        guard lengths > 0.0001 else { return 1 }
        return (ux * vx + uy * vy) / lengths
    }

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

    private static func computeWidths(
        from samples: [Sample],
        config: Config,
        taperStart: Bool = true,
        taperEnd: Bool = true
    ) -> [CGFloat] {
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

        let isFinger = config.widthModel == .finger
        let slowSpeed: CGFloat = isFinger ? Finger.slowSpeed : 100
        let fastSpeed: CGFloat = isFinger ? Finger.fastSpeed : 1500
        let pressureBlend = config.pressureSensitivity.blendFactor
        let tiltBlend = config.tiltSensitivity.blendFactor
        var widths: [CGFloat] = samples.enumerated().map { i, sample in
            let speedT = min(1, max(0, (speeds[i] - slowSpeed) / (fastSpeed - slowSpeed)))
            var width = isFinger
                ? config.maxWidth * (1 - Finger.speedThinning * speedT)
                : config.maxWidth - speedT * (config.maxWidth - config.minWidth)

            if pressureBlend > 0, let force = sample.force, force > 0 {
                let forceT = min(1, pow(force, forceGamma))
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

        if isFinger {
            return widths
        }

        // Taper at start and end
        let taperCount = max(1, min(Int(CGFloat(count) * config.taperFraction), maxTaperSamples))
        if taperStart {
            for i in 0..<min(taperCount, count) {
                let t = CGFloat(i + 1) / CGFloat(taperCount + 1)
                widths[i] *= taperTipFloor + (1 - taperTipFloor) * t
            }
        }
        if taperEnd {
            for i in 0..<min(taperCount, count) {
                let idx = count - 1 - i
                let t = CGFloat(i + 1) / CGFloat(taperCount + 1)
                widths[idx] *= taperTipFloor + (1 - taperTipFloor) * t
            }
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

    private static func buildRibbon(
        points: [CGPoint],
        widths: [CGFloat],
        capStart: Bool,
        capEnd: Bool
    ) -> CGPath {
        guard points.count >= 2 else {
            return dotPath(at: points.first ?? .zero, radius: (widths.first ?? 4) / 2)
        }
        var firstNormal = CGVector(dx: 1, dy: 0)
        var lastNormal = CGVector(dx: 1, dy: 0)

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
            if i == 0 {
                firstNormal = CGVector(dx: nx, dy: ny)
            }
            lastNormal = CGVector(dx: nx, dy: ny)
        }

        let path = CGMutablePath()
        path.move(to: leftEdge[0])
        for p in leftEdge.dropFirst() { path.addLine(to: p) }
        if capEnd, let end = points.last, let width = widths.last {
            addCap(to: path, center: end, normal: lastNormal, radius: width / 2, forward: true)
        }
        for p in rightEdge.reversed() { path.addLine(to: p) }
        if capStart {
            addCap(to: path, center: points[0], normal: firstNormal, radius: widths[0] / 2, forward: false)
        }
        path.closeSubpath()
        return path
    }

    private static func addCap(
        to path: CGMutablePath,
        center: CGPoint,
        normal: CGVector,
        radius: CGFloat,
        forward: Bool
    ) {
        let sign: CGFloat = forward ? 1 : -1
        let nx = normal.dx * sign
        let ny = normal.dy * sign
        let dx = normal.dy * sign
        let dy = -normal.dx * sign
        for k in 1..<capSegments {
            let theta = CGFloat.pi * CGFloat(k) / CGFloat(capSegments)
            let c = cos(theta) * radius
            let s = sin(theta) * radius
            path.addLine(to: CGPoint(x: center.x + c * nx + s * dx, y: center.y + c * ny + s * dy))
        }
    }

    private static func dotPath(at center: CGPoint, radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ), transform: nil)
    }
}
