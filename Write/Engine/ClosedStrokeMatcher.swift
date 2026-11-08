import CoreGraphics

enum ClosedStrokeMatcher {
    private static let closureRatio: CGFloat = 0.1
    private static let startCount = 24
    private static let sweeps: [CGFloat] = [345, 360, 375, 390]

    static func isClosed(_ points: [CGPoint]) -> Bool {
        guard points.count > 8, let first = points.first, let last = points.last else {
            return false
        }
        var length: CGFloat = 0
        for (previous, next) in zip(points, points.dropFirst()) {
            length += hypot(next.x - previous.x, next.y - previous.y)
        }
        return hypot(first.x - last.x, first.y - last.y) < closureRatio * length
    }

    static func distance(user: [CGPoint], closedReference: [CGPoint]) -> CGFloat {
        let ring = Array(closedReference.dropLast())
        let step = max(ring.count / startCount, 1)
        var best = CGFloat.infinity
        for start in stride(from: 0, to: ring.count, by: step) {
            for sweep in sweeps {
                let count = max(Int((CGFloat(ring.count) * sweep / 360).rounded()), 2)
                let arc = (0...count).map { ring[(start + $0) % ring.count] }
                let target = ProcrustesNormalizer.scaleToUnit(ProcrustesNormalizer.translateToOrigin(arc)).points
                best = min(best, FrechetDistance.compute(between: user, and: target))
                best = min(best, FrechetDistance.compute(between: user, and: target.reversed()))
            }
        }
        return best
    }
}
