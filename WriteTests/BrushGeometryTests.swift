import XCTest
import CoreGraphics
@testable import Write

final class BrushGeometryTests: XCTestCase {

    private var pencil: BrushStroke.Config {
        BrushStroke.Config(pressure: .medium, tilt: .off, smoothing: .auto, thickness: .medium)
            .resolved(forPencil: true)
    }

    private var finger: BrushStroke.Config {
        BrushStroke.Config(pressure: .medium, tilt: .off, smoothing: .auto, thickness: .medium)
            .resolved(forPencil: false)
    }

    private var bothModels: [(String, BrushStroke.Config)] {
        [("pencil", pencil), ("finger", finger)]
    }

    func testInkIsTheUnionOfSpineDiscs() {
        let shapes: [(String, [CGPoint])] = [
            ("straight", polyline([CGPoint(x: 20, y: 100), CGPoint(x: 220, y: 100)])),
            ("corner", polyline([CGPoint(x: 20, y: 100), CGPoint(x: 120, y: 100), CGPoint(x: 120, y: 200)])),
            ("v-turn", polyline([
                CGPoint(x: 20, y: 100), CGPoint(x: 120, y: 100),
                CGPoint(x: 120 - 100 * cos(CGFloat.pi / 6), y: 100 + 100 * sin(CGFloat.pi / 6))
            ])),
            ("reversal", polyline([CGPoint(x: 20, y: 100), CGPoint(x: 120, y: 100), CGPoint(x: 40, y: 100)])),
            ("s-curve", (0...200).map { i in
                CGPoint(x: 20 + CGFloat(i), y: 100 + 30 * sin(CGFloat(i) / 25))
            })
        ]
        for (model, config) in bothModels {
            for (shape, points) in shapes {
                let input = timed(points)
                let path = BrushStroke.createPath(from: input, config: config)
                let spine = BrushStroke.spine(from: input, config: config)
                let label = "\(model) \(shape)"
                XCTAssertGreaterThan(spine.count, 20, label)
                XCTAssertEqual(uncoveredProbes(of: spine, in: path), 0, "\(label): spine discs not covered")
                XCTAssertEqual(verticesOutsideDiscs(of: path, spine: spine, tolerance: 0.3), 0, "\(label): ink outside discs")
            }
        }
    }

    func testTipTickChangesOnlyTheEnd() {
        let base = timed(polyline([CGPoint(x: 20, y: 100), CGPoint(x: 120, y: 100)], spacing: 0.5), speed: 60)
        guard let last = base.last else { return XCTFail("Empty stroke") }
        for (model, config) in bothModels {
            let basePath = BrushStroke.createPath(from: base, config: config)
            for k in 0..<8 {
                let angle = CGFloat(k) * .pi / 4
                let tick = BrushStroke.Sample(
                    point: CGPoint(x: last.point.x + cos(angle), y: last.point.y + sin(angle)),
                    timestamp: last.timestamp + 1.0 / 120
                )
                let tickPath = BrushStroke.createPath(from: base + [tick], config: config)
                let raster = BrushRaster(covering: [basePath, tickPath])
                let changes = raster.coarseDifferences(basePath, tickPath) { point in
                    hypot(point.x - last.point.x, point.y - last.point.y) > 6
                }
                XCTAssertEqual(changes.count, 0, "\(model) tick at \(k * 45) degrees: \(changes.prefix(3))")
            }
        }
    }

    func testStartTaperDoesNotDependOnStrokeLength() {
        for (model, config) in bothModels {
            let short = timed(polyline([CGPoint(x: 20, y: 100), CGPoint(x: 140, y: 100)]))
            let long = timed(polyline([CGPoint(x: 20, y: 100), CGPoint(x: 420, y: 100)]))
            let shortPath = BrushStroke.createPath(from: short, config: config)
            let longPath = BrushStroke.createPath(from: long, config: config)
            let raster = BrushRaster(bounds: CGRect(x: 0, y: 80, width: 80, height: 40))
            let area = raster.differingArea(shortPath, longPath) { point in
                hypot(point.x - 20, point.y - 100) < 40
            }
            XCTAssertEqual(area, 0, model)
        }
    }

    func testShortStrokesKeepMostOfTheBodyWidth() {
        for (model, config) in bothModels {
            let long = timed(polyline([CGPoint(x: 20, y: 100), CGPoint(x: 220, y: 100)]))
            let body = BrushStroke.spine(from: long, config: config).radii.max() ?? 0
            for length: CGFloat in [12, 20] {
                let short = timed(polyline([CGPoint(x: 20, y: 100), CGPoint(x: 20 + length, y: 100)]))
                let widest = BrushStroke.spine(from: short, config: config).radii.max() ?? 0
                XCTAssertGreaterThanOrEqual(widest, body * 0.6, "\(model) \(length) pt")
            }
        }
    }

    func testLiveInkFarFromTheTipNeverChanges() {
        let cases: [(String, BrushStroke.Config, CGFloat)] = [("pencil", pencil, 400), ("finger", finger, 160)]
        for (model, config, speed) in cases {
            let input = wave(length: 500, speed: speed)
            let full = BrushStroke.createPath(from: input, config: config)
            let raster = BrushRaster(covering: [full], margin: 12)
            var renderer = BrushStroke.LiveRenderer(config: config)
            var previous: [UInt8]?
            var changed = 0
            for (i, sample) in input.enumerated() {
                renderer.append(sample)
                guard i % 2 == 0 else { continue }
                let mask = raster.mask(renderer.currentPath())
                if let previous {
                    for index in mask.indices where mask[index] != previous[index] {
                        let point = raster.point(index)
                        if hypot(point.x - sample.point.x, point.y - sample.point.y) > 48 {
                            changed += 1
                        }
                    }
                }
                previous = mask
            }
            XCTAssertEqual(changed, 0, model)
        }
    }

    func testDwellAtTheStartNeverLosesLiveInk() {
        let parameters = StrokeHookTrimmer.Parameters(canvasSize: CGSize(width: 400, height: 400))
        let landing = CGPoint(x: 40, y: 100)
        var input = (0..<14).map { i in
            BrushStroke.Sample(
                point: CGPoint(x: landing.x + (i.isMultiple(of: 2) ? 0.3 : -0.3), y: landing.y + (i.isMultiple(of: 3) ? 0.2 : -0.2)),
                timestamp: TimeInterval(i) / 240,
                force: 0.3
            )
        }
        let motion = timed(polyline([landing, CGPoint(x: 200, y: 100)]), speed: 150, force: 0.3)
        let dwellEnd = input.last?.timestamp ?? 0
        input += motion.dropFirst().map {
            BrushStroke.Sample(point: $0.point, timestamp: dwellEnd + $0.timestamp, force: $0.force)
        }
        for (model, config) in bothModels {
            let full = BrushStroke.createPath(from: input, config: config)
            let raster = BrushRaster(covering: [full], margin: 8)
            var ink = BrushInk(config: config, hookParameters: parameters)
            var previous: CGPath?
            var lost = 0
            for sample in input {
                ink.append(sample)
                let current = ink.livePath()
                if let previous {
                    lost += raster.coarseDifferences(previous, current) { previous.contains($0) }.count
                }
                previous = current
            }
            XCTAssertEqual(ink.startIndex, 0, "\(model): the fixture must have no hook")
            XCTAssertEqual(lost, 0, model)
        }
    }

    func testLiveInkEqualsCommittedInk() {
        let parameters = StrokeHookTrimmer.Parameters(canvasSize: CGSize(width: 600, height: 600))
        let cases: [(String, BrushStroke.Config, CGFloat)] = [("pencil", pencil, 400), ("finger", finger, 160)]
        for (model, config, speed) in cases {
            let input = wave(length: 300, speed: speed)
            XCTAssertEqual(
                StrokeHookTrimmer.keptRange(of: input.map(\.point), forces: input.compactMap(\.force), parameters: parameters),
                0..<input.count,
                "\(model): the fixture must have no hook"
            )
            var ink = BrushInk(config: config, hookParameters: parameters)
            var checkpoints: [(CGPath, CGPoint)] = []
            for (i, sample) in input.enumerated() {
                ink.append(sample)
                if i > 0, i % 60 == 0 {
                    checkpoints.append((ink.livePath(), sample.point))
                }
            }
            let committed = ink.committedPath()
            let live = ink.livePath()
            let raster = BrushRaster(covering: [committed, live])
            XCTAssertLessThanOrEqual(raster.differingArea(live, committed), 0.5, model)
            for (path, tip) in checkpoints {
                let area = raster.differingArea(path, committed) { point in
                    point.x < tip.x - 48
                }
                XCTAssertEqual(area, 0, "\(model) checkpoint at x \(tip.x)")
            }
        }
    }

    func testLandingHookLeavesTheLiveInkWhileDrawing() {
        let parameters = StrokeHookTrimmer.Parameters(canvasSize: CGSize(width: 300, height: 300))
        let hookStart = CGPoint(x: 57, y: 93)
        let points = polyline([hookStart, CGPoint(x: 50, y: 100), CGPoint(x: 250, y: 100)])
        let input = timed(points, force: 0.3)
        let trimmedStart = StrokeHookTrimmer.keptRange(
            of: input.map(\.point), forces: input.compactMap(\.force), parameters: parameters
        ).lowerBound
        XCTAssertGreaterThan(trimmedStart, 0, "The fixture must have a landing hook the trimmer removes")

        var ink = BrushInk(config: pencil, hookParameters: parameters)
        var hookGoneAt: CGFloat?
        for sample in input {
            ink.append(sample)
            if hookGoneAt == nil, ink.samples.count > 20, !ink.livePath().contains(hookStart) {
                hookGoneAt = sample.point.x
            }
            if let hookGoneAt, sample.point.x > hookGoneAt {
                XCTAssertFalse(ink.livePath().contains(hookStart), "The hook came back at x \(sample.point.x)")
            }
        }
        guard let hookGoneAt else { return XCTFail("The live ink kept the landing hook") }
        XCTAssertLessThan(hookGoneAt, 150)

        let live = ink.livePath()
        let committed = ink.committedPath()
        XCTAssertFalse(committed.contains(hookStart))
        let raster = BrushRaster(covering: [live, committed])
        let area = raster.differingArea(live, committed) { point in
            hypot(point.x - hookStart.x, point.y - hookStart.y) < 30
        }
        XCTAssertEqual(area, 0)
    }

    func testLiveStartMovesBackOnlyForAtLeastTwoPoints() {
        let arcs = (0..<40).map { CGFloat($0) * 1.2 }
        XCTAssertEqual(BrushInk.liveStart(current: 10, proposed: 14, arcs: arcs), 14)
        XCTAssertEqual(BrushInk.liveStart(current: 10, proposed: 9, arcs: arcs), 10)
        XCTAssertEqual(BrushInk.liveStart(current: 10, proposed: 8, arcs: arcs), 8)
        XCTAssertEqual(BrushInk.liveStart(current: 10, proposed: 7, arcs: arcs), 7)
        XCTAssertEqual(BrushInk.liveStart(current: 10, proposed: 0, arcs: arcs), 0)
    }

    private func polyline(_ corners: [CGPoint], spacing: CGFloat = 1) -> [CGPoint] {
        guard var previous = corners.first else { return [] }
        var points = [previous]
        for corner in corners.dropFirst() {
            let length = hypot(corner.x - previous.x, corner.y - previous.y)
            let steps = max(1, Int((length / spacing).rounded()))
            for k in 1...steps {
                let t = CGFloat(k) / CGFloat(steps)
                points.append(CGPoint(
                    x: previous.x + (corner.x - previous.x) * t,
                    y: previous.y + (corner.y - previous.y) * t
                ))
            }
            previous = corner
        }
        return points
    }

    private func timed(_ points: [CGPoint], speed: CGFloat = 150, force: CGFloat? = nil) -> [BrushStroke.Sample] {
        var time: TimeInterval = 0
        var previous = points.first ?? .zero
        return points.map { point in
            time += TimeInterval(hypot(point.x - previous.x, point.y - previous.y) / speed)
            previous = point
            return BrushStroke.Sample(point: point, timestamp: time, force: force)
        }
    }

    private func wave(length: CGFloat, speed: CGFloat) -> [BrushStroke.Sample] {
        var samples: [BrushStroke.Sample] = []
        var time: TimeInterval = 0
        var x: CGFloat = 20
        while x <= 20 + length {
            let localSpeed = speed * (1 + 0.8 * sin(x / 37))
            samples.append(BrushStroke.Sample(
                point: CGPoint(x: x, y: 200 + 40 * sin(x / 45)),
                timestamp: time,
                force: 0.3 + 0.2 * sin(x / 23)
            ))
            time += 1.0 / 120
            x += localSpeed / 120 * 0.8
        }
        return samples
    }

    private func uncoveredProbes(of spine: BrushSpine, in path: CGPath) -> Int {
        var missing = 0
        for k in spine.points.indices {
            let center = spine.points[k]
            let reach = spine.radii[k] * 0.9
            var probes = [center]
            for j in 0..<8 {
                let angle = CGFloat(j) * .pi / 4
                probes.append(CGPoint(x: center.x + reach * cos(angle), y: center.y + reach * sin(angle)))
                probes.append(CGPoint(x: center.x + reach * 0.5 * cos(angle + 0.4), y: center.y + reach * 0.5 * sin(angle + 0.4)))
            }
            missing += probes.filter { !path.contains($0) }.count
        }
        return missing
    }

    private func verticesOutsideDiscs(of path: CGPath, spine: BrushSpine, tolerance: CGFloat) -> Int {
        var vertices: [CGPoint] = []
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                vertices.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                vertices.append(element.pointee.points[1])
            case .addCurveToPoint:
                vertices.append(element.pointee.points[2])
            default:
                break
            }
        }
        return vertices.filter { vertex in
            !spine.points.indices.contains { k in
                hypot(vertex.x - spine.points[k].x, vertex.y - spine.points[k].y) <= spine.radii[k] + tolerance
            }
        }.count
    }
}
