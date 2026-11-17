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
        renderer(for: samples, config: config).finishedPath()
    }

    static func spine(from samples: [Sample], config: Config = Config()) -> BrushSpine {
        renderer(for: samples, config: config).currentSpine()
    }

    private static func renderer(for samples: [Sample], config: Config) -> LiveRenderer {
        var renderer = LiveRenderer(config: config)
        for sample in samples {
            renderer.append(sample)
        }
        return renderer
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

    static let controlSpacing: CGFloat = 4

    static let speedWindowLength: CGFloat = 28

    static let startTaperWidths: CGFloat = 1.5
    static let endTaperWidths: CGFloat = 3
    static let endTaperMaxFraction: CGFloat = 0.15

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
        static let tipWidths: CGFloat = 2
        static let tipMaxFraction: CGFloat = 0.3
        static let thinningWidths: CGFloat = 25
        static let endWidth: CGFloat = 0.75
    }

    static func bodyWidths(of controls: [Sample], in range: Range<Int>, config: Config) -> [CGFloat] {
        let isFinger = config.widthModel == .finger
        let slowSpeed: CGFloat = isFinger ? Finger.slowSpeed : 100
        let fastSpeed: CGFloat = isFinger ? Finger.fastSpeed : 1500
        let pressureBlend = config.pressureSensitivity.blendFactor
        let tiltBlend = config.tiltSensitivity.blendFactor
        return range.map { i in
            let sample = controls[i]
            let speed = smoothedSpeed(of: controls, at: i)
            let speedT = min(1, max(0, (speed - slowSpeed) / (fastSpeed - slowSpeed)))
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
    }

    static func taperFactor(arc: CGFloat, length: CGFloat, config: Config, taperStart: Bool) -> CGFloat {
        let toEnd = max(0, length - arc)
        switch config.widthModel {
        case .speed:
            var factor: CGFloat = 1
            let startZone = config.maxWidth * startTaperWidths
            if taperStart, arc < startZone {
                factor *= taperTipFloor + (1 - taperTipFloor) * arc / startZone
            }
            let endZone = min(config.maxWidth * endTaperWidths, length * endTaperMaxFraction)
            if toEnd < endZone {
                factor *= taperTipFloor + (1 - taperTipFloor) * toEnd / endZone
            }
            return factor
        case .finger:
            let progress = min(1, arc / (config.maxWidth * Finger.thinningWidths))
            let eased = progress * progress * (3 - 2 * progress)
            var factor = 1 - (1 - Finger.endWidth) * eased
            let pressIn = config.maxWidth * Finger.pressInWidths
            if taperStart, arc < pressIn {
                factor *= Finger.tipFloor + (1 - Finger.tipFloor) * easeOut(arc / pressIn)
            }
            let tip = min(config.maxWidth * Finger.tipWidths, length * Finger.tipMaxFraction)
            if toEnd < tip {
                factor *= Finger.tipFloor + (1 - Finger.tipFloor) * easeOut(toEnd / tip)
            }
            return factor
        }
    }

    private static func easeOut(_ t: CGFloat) -> CGFloat {
        t * (2 - t)
    }

    private static func smoothedSpeed(of controls: [Sample], at index: Int) -> CGFloat {
        var speedSum: CGFloat = 0
        var weightSum: CGFloat = 0
        var reach: CGFloat = 0
        var k = index + 1
        while k < controls.count {
            let length = segmentLength(of: controls, at: k)
            let weight = 1 - (reach + length / 2) / speedWindowLength
            guard weight > 0 else { break }
            accumulate(controls, segment: k, length: length, weight: weight, speedSum: &speedSum, weightSum: &weightSum)
            reach += length
            k += 1
        }
        reach = 0
        k = index
        while k >= 1 {
            let length = segmentLength(of: controls, at: k)
            let weight = 1 - (reach + length / 2) / speedWindowLength
            guard weight > 0 else { break }
            accumulate(controls, segment: k, length: length, weight: weight, speedSum: &speedSum, weightSum: &weightSum)
            reach += length
            k -= 1
        }
        return weightSum > 0 ? speedSum / weightSum : 0
    }

    private static func segmentLength(of controls: [Sample], at k: Int) -> CGFloat {
        let a = controls[k - 1].point
        let b = controls[k].point
        return hypot(b.x - a.x, b.y - a.y)
    }

    private static func accumulate(
        _ controls: [Sample], segment k: Int, length: CGFloat, weight: CGFloat,
        speedSum: inout CGFloat, weightSum: inout CGFloat
    ) {
        let dt = controls[k].timestamp - controls[k - 1].timestamp
        guard dt > 0.0001 else { return }
        speedSum += length / CGFloat(dt) * weight
        weightSum += weight
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
}
