import CoreGraphics

enum KanaStrokeVariants {
    private static let curledStrokes: [Character: [Int]] = [
        "う": [0],
        "え": [0],
        "こ": [0],
        "ご": [0],
        "た": [2],
        "だ": [2],
        "な": [2],
        "に": [1],
        "ふ": [0, 3],
        "ぶ": [0, 3],
        "ぷ": [0, 3],
        "む": [2],
        "や": [1],
        "ら": [0]
    ]
    private static let smallYa: Character = "ゃ"
    private static let smallYaCurlFromEnd = 2
    private static let tailLengths: [CGFloat] = [0, 0.25, 0.5, 0.75, 1.25, 1.5]
    private static let tailSampleCount = 41
    private static let extensionSteps = 4

    static func curledStrokeIndices(text: String, strokeCount: Int) -> Set<Int> {
        guard let first = text.first else {
            return []
        }
        var indices = Set(curledStrokes[first] ?? [])
        if text.count == 2, text.last == smallYa {
            indices.insert(strokeCount - smallYaCurlFromEnd)
        }
        return indices.filter { (0..<strokeCount).contains($0) }
    }

    static func curlVariants(of reference: [CGPoint]) -> [[CGPoint]] {
        guard let corner = curlCorner(in: reference) else {
            return []
        }
        let body = Array(reference[...corner])
        let tail = PointSampler.sample(points: Array(reference[corner...]), count: tailSampleCount)
        return tailLengths.map { length in
            PointSampler.sample(points: body + tailPoints(tail, length: length), count: reference.count)
        }
    }

    private static func curlCorner(in reference: [CGPoint]) -> Int? {
        let count = reference.count
        guard count >= 12 else {
            return nil
        }
        let bodyStart = reference[count / 5]
        let bodyEnd = reference[(count * 11) / 20]
        let dx = bodyEnd.x - bodyStart.x
        let dy = bodyEnd.y - bodyStart.y
        let length = hypot(dx, dy)
        guard length > 0 else {
            return nil
        }
        var corner = (count * 11) / 20
        var farthest = -CGFloat.infinity
        for index in corner..<count {
            let reach = (reference[index].x - bodyStart.x) * dx / length
                + (reference[index].y - bodyStart.y) * dy / length
            if reach > farthest {
                farthest = reach
                corner = index
            }
        }
        return corner < count - 1 ? corner : nil
    }

    private static func tailPoints(_ tail: [CGPoint], length: CGFloat) -> [CGPoint] {
        let steps = tail.count - 1
        guard length > 1 else {
            return Array(tail.dropFirst().prefix(Int(CGFloat(steps) * length)))
        }
        guard let last = tail.last else {
            return []
        }
        let previous = tail[steps * 4 / 5]
        let dx = last.x - previous.x
        let dy = last.y - previous.y
        let direction = max(hypot(dx, dy), .leastNonzeroMagnitude)
        var tailLength: CGFloat = 0
        for (from, to) in zip(tail, tail.dropFirst()) {
            tailLength += hypot(to.x - from.x, to.y - from.y)
        }
        let extra = tailLength * (length - 1)
        let extended = (1...extensionSteps).map { step -> CGPoint in
            let reach = extra * CGFloat(step) / CGFloat(extensionSteps) / direction
            return CGPoint(x: last.x + dx * reach, y: last.y + dy * reach)
        }
        return Array(tail.dropFirst()) + extended
    }
}
