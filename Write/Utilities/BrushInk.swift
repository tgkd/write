import CoreGraphics

struct BrushInk {
    let config: BrushStroke.Config
    let hookParameters: StrokeHookTrimmer.Parameters
    private(set) var samples: [BrushStroke.Sample] = []
    private(set) var startIndex = 0
    private var startSettled = false
    private var arcs: [CGFloat] = []
    private var renderer: BrushStroke.LiveRenderer

    init(config: BrushStroke.Config, hookParameters: StrokeHookTrimmer.Parameters) {
        self.config = config
        self.hookParameters = hookParameters
        renderer = BrushStroke.LiveRenderer(config: config)
    }

    mutating func append(_ sample: BrushStroke.Sample) {
        let step = samples.last.map { hypot(sample.point.x - $0.point.x, sample.point.y - $0.point.y) } ?? 0
        arcs.append((arcs.last ?? 0) + step)
        samples.append(sample)
        renderer.append(sample)
        if !startSettled {
            decideStart()
        }
    }

    mutating func refine(rawIndex: Int, force: CGFloat?, altitude: CGFloat?) {
        guard samples.indices.contains(rawIndex) else { return }
        let sample = samples[rawIndex]
        samples[rawIndex] = BrushStroke.Sample(
            point: sample.point, timestamp: sample.timestamp, force: force, altitude: altitude
        )
        if rawIndex >= startIndex {
            renderer.refine(rawIndex: rawIndex - startIndex, force: force, altitude: altitude)
        }
    }

    func livePath() -> CGPath {
        renderer.currentPath()
    }

    func predictedPath(with predictedSamples: [BrushStroke.Sample]) -> CGPath {
        renderer.predictedPath(with: predictedSamples)
    }

    func committedPath() -> CGPath {
        Self.committedPath(from: samples, startIndex: startIndex, config: config, hookParameters: hookParameters)
    }

    static func committedPath(
        from samples: [BrushStroke.Sample],
        startIndex: Int,
        config: BrushStroke.Config,
        hookParameters: StrokeHookTrimmer.Parameters
    ) -> CGPath {
        let range = committedRange(of: samples, startIndex: startIndex, hookParameters: hookParameters)
        return BrushStroke.createPath(from: Array(samples[range]), config: config)
    }

    static func committedRange(
        of samples: [BrushStroke.Sample],
        startIndex: Int,
        hookParameters: StrokeHookTrimmer.Parameters
    ) -> Range<Int> {
        guard startIndex < samples.count else { return samples.indices }
        let end = StrokeHookTrimmer.keptRange(
            of: samples.map(\.point),
            forces: samples.compactMap(\.force),
            parameters: hookParameters
        ).upperBound
        return startIndex..<(end > startIndex ? end : samples.count)
    }

    static let startReturnArc: CGFloat = 2

    static func liveStart(current: Int, proposed: Int, arcs: [CGFloat]) -> Int {
        guard proposed < current else { return proposed }
        return arcs[current] - arcs[proposed] >= startReturnArc ? proposed : current
    }

    private mutating func decideStart() {
        if (arcs.last ?? 0) >= StrokeHookTrimmer.startDecisionLength(parameters: hookParameters) {
            startSettled = true
        }
        let proposed = StrokeHookTrimmer.keptRange(
            of: samples.map(\.point),
            forces: samples.compactMap(\.force),
            parameters: hookParameters
        ).lowerBound
        let start = Self.liveStart(current: startIndex, proposed: proposed, arcs: arcs)
        guard start != startIndex else { return }
        startIndex = start
        renderer = BrushStroke.LiveRenderer(config: config)
        for sample in samples[start...] {
            renderer.append(sample)
        }
    }
}
