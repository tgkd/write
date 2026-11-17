import CoreGraphics

enum BrushOutline {

    static let arcStep: CGFloat = .pi / 8
    static let joinAngle: CGFloat = 0.2
    private static let mergeDistance: CGFloat = 0.0001

    private struct Segment {
        let left: CGVector
        let right: CGVector
        let contained: Bool
    }

    static func append(_ spine: BrushSpine, range: ClosedRange<Int>, to path: CGMutablePath) {
        var centers: [CGPoint] = []
        var radii: [CGFloat] = []
        for k in range {
            let point = spine.points[k]
            let radius = max(0, spine.radii[k])
            if let last = centers.last, hypot(point.x - last.x, point.y - last.y) < mergeDistance {
                radii[radii.count - 1] = max(radii[radii.count - 1], radius)
                continue
            }
            centers.append(point)
            radii.append(radius)
        }
        guard centers.count >= 2 else {
            if let center = centers.first {
                appendDisc(center: center, radius: radii[0], to: path)
            }
            return
        }

        let segments = (0..<(centers.count - 1)).map { i in
            segment(from: centers[i], radius: radii[i], to: centers[i + 1], radius: radii[i + 1])
        }
        var left: [[CGVector]] = []
        var right: [[CGVector]] = []
        for i in centers.indices {
            let incoming = i > 0 && !segments[i - 1].contained ? segments[i - 1] : nil
            let outgoing = i < segments.count && !segments[i].contained ? segments[i] : nil
            switch (incoming, outgoing) {
            case let (incoming?, outgoing?):
                left.append(sideDirections(from: incoming.left, to: outgoing.left))
                right.append(sideDirections(from: outgoing.right, to: incoming.right))
            case let (incoming?, nil):
                left.append([incoming.left])
                right.append([incoming.right])
            case let (nil, outgoing?):
                left.append([outgoing.left])
                right.append([outgoing.right])
            case (nil, nil):
                left.append([CGVector(dx: 0, dy: 1)])
                right.append([CGVector(dx: 0, dy: -1)])
            }
        }

        var runStart = 0
        for i in segments.indices {
            let valid = !segments[i].contained && isValid(
                from: centers[i], radius: radii[i], to: centers[i + 1], radius: radii[i + 1],
                leftFrom: left[i].last!, leftTo: left[i + 1].first!,
                rightFrom: right[i].first!, rightTo: right[i + 1].last!
            )
            guard !valid else { continue }
            if runStart < i {
                appendRun(centers: centers, radii: radii, left: left, right: right, range: runStart...i, to: path)
            }
            appendCapsule(
                from: centers[i], radius: radii[i], to: centers[i + 1], radius: radii[i + 1],
                segment: segments[i], to: path
            )
            runStart = i + 1
        }
        if runStart < centers.count - 1 {
            appendRun(
                centers: centers, radii: radii, left: left, right: right,
                range: runStart...(centers.count - 1), to: path
            )
        }
    }

    static func appendDisc(center: CGPoint, radius: CGFloat, to path: CGMutablePath) {
        let start = CGVector(dx: 1, dy: 0)
        path.move(to: offset(center, radius, start))
        appendArc(center: center, radius: radius, from: start, sweep: -2 * .pi, to: path)
        path.closeSubpath()
    }

    private static func segment(from a: CGPoint, radius ra: CGFloat, to b: CGPoint, radius rb: CGFloat) -> Segment {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = hypot(dx, dy)
        let tangent = CGVector(dx: dx / length, dy: dy / length)
        let normal = CGVector(dx: -tangent.dy, dy: tangent.dx)
        let tilt = (ra - rb) / length
        guard abs(tilt) < 1 else {
            return Segment(left: normal, right: CGVector(dx: -normal.dx, dy: -normal.dy), contained: true)
        }
        let spread = sqrt(1 - tilt * tilt)
        return Segment(
            left: CGVector(dx: tilt * tangent.dx + spread * normal.dx, dy: tilt * tangent.dy + spread * normal.dy),
            right: CGVector(dx: tilt * tangent.dx - spread * normal.dx, dy: tilt * tangent.dy - spread * normal.dy),
            contained: false
        )
    }

    private static func sideDirections(from a: CGVector, to b: CGVector) -> [CGVector] {
        let sweep = signedAngle(from: a, to: b)
        if sweep < -joinAngle {
            let steps = max(1, Int((-sweep / arcStep).rounded(.up)))
            let start = atan2(a.dy, a.dx)
            var directions = [a]
            for k in 1..<steps {
                let angle = start + sweep * CGFloat(k) / CGFloat(steps)
                directions.append(CGVector(dx: cos(angle), dy: sin(angle)))
            }
            directions.append(b)
            return directions
        }
        let sum = CGVector(dx: a.dx + b.dx, dy: a.dy + b.dy)
        let length = hypot(sum.dx, sum.dy)
        guard length > 0.000001 else { return [a] }
        return [CGVector(dx: sum.dx / length, dy: sum.dy / length)]
    }

    private static func isValid(
        from a: CGPoint, radius ra: CGFloat, to b: CGPoint, radius rb: CGFloat,
        leftFrom: CGVector, leftTo: CGVector, rightFrom: CGVector, rightTo: CGVector
    ) -> Bool {
        let leftA = offset(a, ra, leftFrom)
        let leftB = offset(b, rb, leftTo)
        let rightA = offset(a, ra, rightFrom)
        let rightB = offset(b, rb, rightTo)
        return cross(leftA, leftB, b) < tolerance
            && cross(leftA, b, a) < tolerance
            && cross(a, b, rightB) < tolerance
            && cross(a, rightB, rightA) < tolerance
    }

    private static let tolerance: CGFloat = 0.000000001

    private static func appendRun(
        centers: [CGPoint], radii: [CGFloat], left: [[CGVector]], right: [[CGVector]],
        range: ClosedRange<Int>, to path: CGMutablePath
    ) {
        let first = range.lowerBound
        let last = range.upperBound
        path.move(to: offset(centers[first], radii[first], left[first][0]))
        for direction in left[first].dropFirst() {
            path.addLine(to: offset(centers[first], radii[first], direction))
        }
        for i in (first + 1)...last {
            for direction in left[i] {
                path.addLine(to: offset(centers[i], radii[i], direction))
            }
        }
        appendCap(center: centers[last], radius: radii[last], from: left[last].last!, to: right[last][0], to: path)
        for i in stride(from: last, through: first, by: -1) {
            for direction in right[i] {
                path.addLine(to: offset(centers[i], radii[i], direction))
            }
        }
        appendCap(center: centers[first], radius: radii[first], from: right[first].last!, to: left[first][0], to: path)
        path.closeSubpath()
    }

    private static func appendCapsule(
        from a: CGPoint, radius ra: CGFloat, to b: CGPoint, radius rb: CGFloat,
        segment: Segment, to path: CGMutablePath
    ) {
        guard !segment.contained else {
            if ra >= rb {
                appendDisc(center: a, radius: ra, to: path)
            } else {
                appendDisc(center: b, radius: rb, to: path)
            }
            return
        }
        path.move(to: offset(a, ra, segment.left))
        path.addLine(to: offset(b, rb, segment.left))
        appendCap(center: b, radius: rb, from: segment.left, to: segment.right, to: path)
        path.addLine(to: offset(a, ra, segment.right))
        appendCap(center: a, radius: ra, from: segment.right, to: segment.left, to: path)
        path.closeSubpath()
    }

    private static func appendCap(
        center: CGPoint, radius: CGFloat, from a: CGVector, to b: CGVector, to path: CGMutablePath
    ) {
        var sweep = signedAngle(from: a, to: b)
        if sweep >= 0 {
            sweep -= 2 * .pi
        }
        appendArc(center: center, radius: radius, from: a, sweep: sweep, to: path)
    }

    private static func appendArc(
        center: CGPoint, radius: CGFloat, from a: CGVector, sweep: CGFloat, to path: CGMutablePath
    ) {
        let steps = max(1, Int((abs(sweep) / arcStep).rounded(.up)))
        let start = atan2(a.dy, a.dx)
        for k in 1...steps {
            let angle = start + sweep * CGFloat(k) / CGFloat(steps)
            path.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
        }
    }

    private static func signedAngle(from a: CGVector, to b: CGVector) -> CGFloat {
        atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy)
    }

    private static func offset(_ center: CGPoint, _ radius: CGFloat, _ direction: CGVector) -> CGPoint {
        CGPoint(x: center.x + radius * direction.dx, y: center.y + radius * direction.dy)
    }

    private static func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
}
