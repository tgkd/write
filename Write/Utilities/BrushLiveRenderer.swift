import CoreGraphics

extension BrushStroke {

    struct LiveRenderer {

        static let tailWindow = 16

        private let config: Config
        private var kept: [Sample] = []
        private var keptRawIndices: [Int] = []
        private var provisional: Sample?
        private var provisionalRawIndex: Int?
        private var rawCount = 0
        private var frozenPath = CGMutablePath()
        private var frozenSpine = BrushSpine()
        private var frozenControls = 0
        private var frozenArc: CGFloat = 0

        init(config: Config) {
            self.config = config
        }

        mutating func append(_ sample: Sample) {
            if let candidate = provisional, let rawIndex = provisionalRawIndex {
                if kept.last.map({ distance(candidate.point, $0.point) >= BrushStroke.controlSpacing }) ?? true {
                    kept.append(candidate)
                    keptRawIndices.append(rawIndex)
                }
            }
            provisional = sample
            provisionalRawIndex = rawCount
            rawCount += 1
            freezeIfNeeded()
        }

        mutating func refine(rawIndex: Int, force: CGFloat?, altitude: CGFloat?) {
            if provisionalRawIndex == rawIndex, let sample = provisional {
                provisional = Sample(point: sample.point, timestamp: sample.timestamp, force: force, altitude: altitude)
                return
            }
            var i = keptRawIndices.count - 1
            while i >= frozenControls {
                if keptRawIndices[i] == rawIndex {
                    let sample = kept[i]
                    kept[i] = Sample(point: sample.point, timestamp: sample.timestamp, force: force, altitude: altitude)
                    return
                }
                i -= 1
            }
        }

        func currentPath() -> CGPath {
            path(dotRadius: liveDotRadius)
        }

        func finishedPath() -> CGPath {
            path(dotRadius: { _ in config.maxWidth / 2 })
        }

        private func path(dotRadius: ([Sample]) -> CGFloat) -> CGPath {
            let controls = renderControls()
            guard controls.count >= 2 else {
                return dotPath(controls, radius: dotRadius(controls))
            }
            let path = CGMutablePath()
            path.addPath(frozenPath)
            let spine = tailSpine(of: controls, taperStart: true)
            appendChunks(of: spine, controlCount: controls.count, from: frozenControls, to: path)
            return path
        }

        func currentSpine() -> BrushSpine {
            let controls = renderControls()
            guard controls.count >= 2 else {
                return BrushSpine(
                    points: controls.map(\.point),
                    radii: controls.map { _ in config.maxWidth / 2 },
                    arcs: controls.map { _ in 0 }
                )
            }
            var spine = frozenSpine
            let tail = tailSpine(of: controls, taperStart: true)
            spine.append(tail, range: 0..<tail.count)
            return spine
        }

        func predictedPath(with predictedSamples: [Sample]) -> CGPath {
            var controls = renderControls()
            guard let tip = controls.last else { return CGMutablePath() }
            var previous = tip.point
            for sample in predictedSamples where distance(sample.point, previous) >= BrushStroke.controlSpacing / 2 {
                controls.append(sample)
                previous = sample.point
            }
            let stubStart = min(max(frozenControls, kept.count - 4), controls.count - 1)
            let spine = tailSpine(of: controls, taperStart: false)
            let path = CGMutablePath()
            let first = (stubStart - frozenControls) * config.smoothingSubdivisions
            BrushOutline.append(spine, range: first...(spine.count - 1), to: path)
            return path
        }

        func renderControls() -> [Sample] {
            var controls = kept
            guard let tip = provisional else { return controls }
            let tipIsClose = controls.last.map {
                distance(tip.point, $0.point) < BrushStroke.controlSpacing / 2
            } ?? false
            if tipIsClose, controls.count >= 2 {
                controls[controls.count - 1] = tip
            } else if !tipIsClose {
                controls.append(tip)
            }
            return controls
        }

        private func tailSpine(of controls: [Sample], taperStart: Bool) -> BrushSpine {
            BrushSpine.build(
                controls: controls, from: frozenControls, startArc: frozenArc,
                config: config, taperStart: taperStart
            )
        }

        private func appendChunks(of spine: BrushSpine, controlCount: Int, from first: Int, to path: CGMutablePath) {
            let subdivisions = config.smoothingSubdivisions
            var chunkStart = first
            while chunkStart < controlCount - 1 {
                let chunkEnd = min(chunkStart + Self.tailWindow, controlCount - 1)
                BrushOutline.append(
                    spine,
                    range: ((chunkStart - first) * subdivisions)...((chunkEnd - first) * subdivisions),
                    to: path
                )
                chunkStart = chunkEnd
            }
        }

        private var finalControlLimit: Int {
            kept.count - 2 - (config.centerlineRadius + 2)
        }

        private func speedWindowIsFinal(at control: Int) -> Bool {
            var reach: CGFloat = 0
            var k = control + 1
            while k <= kept.count - 2 {
                reach += distance(kept[k - 1].point, kept[k].point)
                if reach >= BrushStroke.speedWindowLength {
                    return true
                }
                k += 1
            }
            return false
        }

        private mutating func freezeIfNeeded() {
            guard frozenControls + Self.tailWindow <= finalControlLimit else { return }
            let controls = renderControls()
            let spine = tailSpine(of: controls, taperStart: true)
            let length = spine.length
            let margin = 2 * BrushStroke.controlSpacing
            let endZone = config.maxWidth * BrushStroke.endTaperWidths
            let subdivisions = config.smoothingSubdivisions
            let base = frozenControls
            while frozenControls + Self.tailWindow <= finalControlLimit {
                let chunkEnd = frozenControls + Self.tailWindow
                let firstVertex = (frozenControls - base) * subdivisions
                let lastVertex = (chunkEnd - base) * subdivisions
                guard speedWindowIsFinal(at: chunkEnd),
                      spine.arcs[lastVertex] <= length - endZone - margin else { return }
                BrushOutline.append(spine, range: firstVertex...lastVertex, to: frozenPath)
                frozenSpine.append(spine, range: firstVertex..<lastVertex)
                frozenArc = spine.arcs[lastVertex]
                frozenControls = chunkEnd
            }
        }

        private func liveDotRadius(_ controls: [Sample]) -> CGFloat {
            guard !controls.isEmpty else { return 0 }
            let body = BrushStroke.bodyWidths(of: controls, in: 0..<1, config: config)[0]
            let floor = BrushStroke.taperFactor(
                arc: 0, length: .greatestFiniteMagnitude, config: config, taperStart: true
            )
            return body * floor / 2
        }

        private func dotPath(_ controls: [Sample], radius: CGFloat) -> CGPath {
            let path = CGMutablePath()
            if let center = controls.first?.point {
                BrushOutline.appendDisc(center: center, radius: radius, to: path)
            }
            return path
        }

        private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            hypot(a.x - b.x, a.y - b.y)
        }
    }
}
