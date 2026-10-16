import Foundation
import CoreGraphics

enum StrokeHookTrimmer {

    struct Parameters {
        var maxHookLength: CGFloat = 6
        var maxHookFraction: CGFloat = 0.08
        var minStrokeLength: CGFloat = 24
        var minPointCount = 6
        var minTurnAngle: CGFloat = 80 * .pi / 180

        init() {}

        init(canvasSize: CGSize) {
            let shortSide = min(canvasSize.width, canvasSize.height)
            let hookLength = min(8, max(4, shortSide * 0.02))
            maxHookLength = hookLength
            minStrokeLength = hookLength * 4
        }
    }

    static func trim(_ points: [CGPoint], parameters: Parameters = Parameters()) -> [CGPoint] {
        Array(points[keptRange(of: points, parameters: parameters)])
    }

    static func keptRange(of points: [CGPoint], parameters: Parameters = Parameters()) -> Range<Int> {
        let full = 0..<points.count
        guard points.count >= parameters.minPointCount else {
            return full
        }
        let arc = arcLengths(points)
        guard let total = arc.last, total >= parameters.minStrokeLength else {
            return full
        }

        let reversed = Array(points.reversed())
        let reversedArc = arcLengths(reversed)
        let first = hookCorner(points: reversed, arc: reversedArc, parameters: parameters)
            .map { points.count - 1 - $0 } ?? 0
        let last = hookCorner(points: points, arc: arc, parameters: parameters) ?? points.count - 1

        guard last - first + 1 >= parameters.minPointCount else {
            return full
        }
        return first..<(last + 1)
    }

    private static func hookCorner(points: [CGPoint], arc: [CGFloat], parameters: Parameters) -> Int? {
        guard let total = arc.last, let end = points.last else {
            return nil
        }
        let window = min(parameters.maxHookLength, parameters.maxHookFraction * total)
        let searchLength = window * 2
        let referenceLength = max(window * 3, total * 0.15)
        let minTail = window * 0.15

        var regionStart = points.count - 1
        while regionStart > 1, total - arc[regionStart - 1] <= searchLength {
            regionStart -= 1
        }
        let anchorIndex = referenceIndex(before: regionStart, arc: arc, length: referenceLength)
        guard anchorIndex < regionStart, regionStart <= points.count - 2 else {
            return nil
        }
        let anchor = points[anchorIndex]
        let main = CGVector(dx: points[regionStart].x - anchor.x, dy: points[regionStart].y - anchor.y)
        let mainNorm = hypot(main.dx, main.dy)
        guard mainNorm >= window else {
            return nil
        }
        let ux = main.dx / mainNorm
        let uy = main.dy / mainNorm

        var corner = regionStart
        var bestScore = -CGFloat.infinity
        for k in regionStart..<points.count {
            let dx = points[k].x - anchor.x
            let dy = points[k].y - anchor.y
            let score = dx * ux + dy * uy - lateralPenalty * abs(dy * ux - dx * uy)
            if score > bestScore {
                bestScore = score
                corner = k
            }
        }
        guard corner < points.count - 1, total - arc[corner] <= window else {
            return nil
        }

        let tail = CGVector(dx: end.x - points[corner].x, dy: end.y - points[corner].y)
        let tailNorm = hypot(tail.dx, tail.dy)
        guard tailNorm >= minTail else {
            return nil
        }
        let cosine = (ux * tail.dx + uy * tail.dy) / tailNorm
        guard cosine < cos(parameters.minTurnAngle) else {
            return nil
        }
        return corner
    }

    private static let lateralPenalty: CGFloat = 0.35

    private static func referenceIndex(before index: Int, arc: [CGFloat], length: CGFloat) -> Int {
        let target = arc[index] - length
        var i = index
        while i > 0, arc[i] > target {
            i -= 1
        }
        return i
    }

    private static func arcLengths(_ points: [CGPoint]) -> [CGFloat] {
        guard let first = points.first else {
            return []
        }
        var result: [CGFloat] = [0]
        result.reserveCapacity(points.count)
        var previous = first
        var sum: CGFloat = 0
        for point in points.dropFirst() {
            sum += hypot(point.x - previous.x, point.y - previous.y)
            result.append(sum)
            previous = point
        }
        return result
    }
}
