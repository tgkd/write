import CoreGraphics
import Foundation
@testable import Write

extension SyntheticStrokeCorpus {
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            return SeededGenerator.mix(state)
        }

        mutating func unit() -> CGFloat {
            CGFloat(next() >> 11) / CGFloat(UInt64(1) << 53)
        }

        mutating func uniform(_ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            lower + (upper - lower) * unit()
        }

        mutating func index(below count: Int) -> Int {
            Int(next() % UInt64(max(count, 1)))
        }

        static func mix(_ value: UInt64) -> UInt64 {
            var z = value
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    struct CorpusCharacter {
        let codePoint: String
        let strokes: [KanjiStroke]

        var scalar: UInt64 {
            UInt64(codePoint, radix: 16) ?? 0
        }
    }

    enum CorpusMistake: String, CaseIterable {
        case substituted
        case reversed
        case truncated
        case shifted
    }

    struct CorpusTally: Equatable {
        var judged = 0
        var hits = 0

        var rate: Double {
            judged > 0 ? Double(hits) / Double(judged) : 0
        }

        var formatted: String {
            String(format: "%4d/%-5d %5.1f%%", hits, judged, rate * 100)
        }

        static func + (lhs: CorpusTally, rhs: CorpusTally) -> CorpusTally {
            CorpusTally(judged: lhs.judged + rhs.judged, hits: lhs.hits + rhs.hits)
        }
    }

    struct CorpusSession {
        let rejected: Int
        let rejectedStrokes: [Bool]
        let proportionEvidence: [Bool?]
        let anchorsBefore: [[StrokeAnchor]]
    }

    struct CorpusReport {
        var falseRejects: [CGFloat: CorpusTally] = [:]
        var rejectedCharacters: [CGFloat: CorpusTally] = [:]
        var falseAccepts: [CorpusMistake: CorpusTally] = [:]
        var falseRejectsByAnchorCount: [Int: Int] = [:]
        var disproportionateCorrectStrokes = CorpusTally()

        var totalFalseAccepts: CorpusTally {
            falseAccepts.values.reduce(CorpusTally(), +)
        }

        var totalFalseRejects: CorpusTally {
            falseRejects.values.reduce(CorpusTally(), +)
        }
    }
}

enum SyntheticStrokeCorpus {
    static let canvasSize = CGSize(width: 300, height: 300)
    static let correctScales: [CGFloat] = [0.7, 0.85, 1.0, 1.2]
    static let mistakeBaseScales: [CGFloat] = [0.85, 1.0, 1.2]
    static let mistakeStrokesPerCharacter = 3
    static let truncatedFraction: CGFloat = 0.45
    static let shiftFraction: CGFloat = 0.25
    static let denseSampleCount = 64

    static func select(
        from entries: [(codePoint: String, strokes: [KanjiStroke])],
        strokeCounts: ClosedRange<Int>,
        limit: Int
    ) -> [CorpusCharacter] {
        let candidates = entries.compactMap { entry -> CorpusCharacter? in
            guard let scalar = UInt32(entry.codePoint, radix: 16),
                  (0x4E00...0x9FFF).contains(scalar),
                  strokeCounts.contains(entry.strokes.count) else {
                return nil
            }
            return CorpusCharacter(codePoint: entry.codePoint, strokes: entry.strokes)
        }
        let ordered = candidates.sorted {
            let lhs = SeededGenerator.mix($0.scalar &+ 0x5EED)
            let rhs = SeededGenerator.mix($1.scalar &+ 0x5EED)
            return lhs == rhs ? $0.scalar < $1.scalar : lhs < rhs
        }
        return Array(ordered.prefix(limit))
    }

    static func isHeldOut(_ character: CorpusCharacter) -> Bool {
        SeededGenerator.mix(character.scalar &* 31 &+ 0xD1CE) % 2 == 0
    }

    static func evaluate(_ characters: [CorpusCharacter], configs: [ValidationConfig]) -> [CorpusReport] {
        var reports = Array(repeating: CorpusReport(), count: configs.count)
        for character in characters {
            evaluate(character, configs: configs, into: &reports)
        }
        return reports
    }

    private static func evaluate(
        _ character: CorpusCharacter,
        configs: [ValidationConfig],
        into reports: inout [CorpusReport]
    ) {
        let samples = StrokeValidator.sampleReferenceStrokes(
            character.strokes, canvasSize: canvasSize, sampleCount: ValidationConfig.standard.sampleCount
        )
        let dense = StrokeValidator.sampleReferenceStrokes(
            character.strokes, canvasSize: canvasSize, sampleCount: denseSampleCount
        )
        guard !dense.contains(where: \.isEmpty), !samples.contains(where: \.isEmpty) else {
            return
        }

        for (scaleIndex, scale) in correctScales.enumerated() {
            var rng = SeededGenerator(seed: character.scalar &* 1_000 &+ UInt64(scaleIndex))
            let user = render(dense, scale: scale, rng: &rng)
            for (configIndex, config) in configs.enumerated() {
                let session = simulateSession(user: user, samples: samples, config: config)
                record(session, strokes: user.count, scale: scale, into: &reports[configIndex])
            }
        }

        guard character.strokes.count >= 2 else {
            return
        }
        let substitutes = character.strokes.indices.map { target in
            character.strokes.indices.filter { other in
                other != target
                    && shapeDistance(samples[other], samples[target]) > ValidationConfig.standard.shapeThreshold * 1.3
            }
        }
        for (scaleIndex, scale) in mistakeBaseScales.enumerated() {
            var rng = SeededGenerator(seed: character.scalar &* 1_000 &+ 100 &+ UInt64(scaleIndex))
            let user = render(dense, scale: scale, rng: &rng)
            var targets = Array(1..<character.strokes.count)
            var chosen: [Int] = []
            while chosen.count < mistakeStrokesPerCharacter, !targets.isEmpty {
                chosen.append(targets.remove(at: rng.index(below: targets.count)))
            }
            var trials: [(target: Int, mistake: CorpusMistake, points: [CGPoint])] = []
            for target in chosen.sorted() {
                for mistake in CorpusMistake.allCases {
                    if let wrong = mistaken(mistake, target: target, user: user, substitutes: substitutes[target], rng: &rng) {
                        trials.append((target, mistake, wrong))
                    }
                }
            }
            for (configIndex, config) in configs.enumerated() {
                let session = simulateSession(user: user, samples: samples, config: config)
                for trial in trials {
                    let result = StrokeValidator.identifyStroke(
                        userPoints: trial.points,
                        referenceSamples: samples,
                        unmatchedIndices: Set(trial.target..<character.strokes.count),
                        canvasSize: canvasSize,
                        expectedStrokeIndex: trial.target,
                        anchors: session.anchorsBefore[trial.target],
                        config: config
                    )
                    reports[configIndex].falseAccepts[trial.mistake, default: CorpusTally()].judged += 1
                    if result.accepted && result.correctOrder {
                        reports[configIndex].falseAccepts[trial.mistake, default: CorpusTally()].hits += 1
                    }
                }
            }
        }
    }

    private static func record(
        _ session: CorpusSession,
        strokes: Int,
        scale: CGFloat,
        into report: inout CorpusReport
    ) {
        for (index, rejected) in session.rejectedStrokes.enumerated() where rejected {
            report.falseRejectsByAnchorCount[min(index, 2), default: 0] += 1
        }
        report.disproportionateCorrectStrokes.judged += session.proportionEvidence.compactMap { $0 }.count
        report.disproportionateCorrectStrokes.hits += session.proportionEvidence.filter { $0 == false }.count
        report.falseRejects[scale, default: CorpusTally()].judged += strokes
        report.falseRejects[scale, default: CorpusTally()].hits += session.rejected
        report.rejectedCharacters[scale, default: CorpusTally()].judged += 1
        report.rejectedCharacters[scale, default: CorpusTally()].hits += session.rejected > 0 ? 1 : 0
    }

    static func simulateSession(
        user: [[CGPoint]],
        samples: [[CGPoint]],
        config: ValidationConfig
    ) -> CorpusSession {
        var anchors: [StrokeAnchor] = []
        var anchorsBefore: [[StrokeAnchor]] = []
        var rejected = 0
        var rejectedStrokes: [Bool] = []
        var proportionEvidence: [Bool?] = []
        for index in user.indices {
            anchorsBefore.append(anchors)
            let result = StrokeValidator.identifyStroke(
                userPoints: user[index],
                referenceSamples: samples,
                unmatchedIndices: Set(index..<user.count),
                canvasSize: canvasSize,
                expectedStrokeIndex: index,
                anchors: anchors,
                config: config
            )
            proportionEvidence.append(result.matchedStrokeIndex == index ? result.evidence.proportionPassed : nil)
            if result.accepted, result.correctOrder, let anchor = result.anchor {
                anchors.append(anchor)
                rejectedStrokes.append(false)
            } else {
                rejected += 1
                rejectedStrokes.append(true)
                let sampled = PointSampler.sample(points: user[index], count: config.sampleCount)
                anchors.append(StrokeAnchor(
                    referenceIndex: index,
                    userCentroid: ProcrustesNormalizer.centroid(of: sampled),
                    userExtent: StrokeValidator.extent(of: sampled)
                ))
            }
        }
        return CorpusSession(
            rejected: rejected,
            rejectedStrokes: rejectedStrokes,
            proportionEvidence: proportionEvidence,
            anchorsBefore: anchorsBefore
        )
    }

    static func render(_ dense: [[CGPoint]], scale: CGFloat, rng: inout SeededGenerator) -> [[CGPoint]] {
        let all = dense.flatMap { $0 }
        let bounds = boundingBox(of: all)
        let pivot = CGPoint(
            x: bounds.midX + rng.uniform(-15, 15),
            y: bounds.midY + rng.uniform(-15, 15)
        )
        let drift = CGVector(dx: rng.uniform(-12, 12), dy: rng.uniform(-12, 12))
        var strokes = dense.map { stroke in
            stroke.map { point in
                CGPoint(
                    x: pivot.x + scale * (point.x - pivot.x) + drift.dx,
                    y: pivot.y + scale * (point.y - pivot.y) + drift.dy
                )
            }
        }
        strokes = strokes.map { jittered($0, rng: &rng) }
        let margin: CGFloat = 4
        let drawn = boundingBox(of: strokes.flatMap { $0 })
        let shrink = min(
            1,
            (canvasSize.width - 2 * margin) / max(drawn.width, 1),
            (canvasSize.height - 2 * margin) / max(drawn.height, 1)
        )
        if shrink < 1 {
            strokes = strokes.map { stroke in
                stroke.map { point in
                    CGPoint(
                        x: drawn.midX + shrink * (point.x - drawn.midX),
                        y: drawn.midY + shrink * (point.y - drawn.midY)
                    )
                }
            }
        }
        let placed = boundingBox(of: strokes.flatMap { $0 })
        let correction = CGVector(
            dx: fit(placed.minX, placed.maxX, upper: canvasSize.width, margin: margin),
            dy: fit(placed.minY, placed.maxY, upper: canvasSize.height, margin: margin)
        )
        return strokes.map { stroke in
            stroke.map { CGPoint(x: $0.x + correction.dx, y: $0.y + correction.dy) }
        }
    }

    private static func jittered(_ stroke: [CGPoint], rng: inout SeededGenerator) -> [CGPoint] {
        let centroid = ProcrustesNormalizer.centroid(of: stroke)
        let offset = CGVector(dx: rng.uniform(-7, 7), dy: rng.uniform(-7, 7))
        let size = rng.uniform(0.85, 1.15)
        let angle = rng.uniform(-0.06, 0.06)
        let wobble = rng.uniform(0.5, 1.5)
        let frequency = rng.uniform(1, 2.5)
        let phase = CGVector(dx: rng.uniform(0, 2 * .pi), dy: rng.uniform(0, 2 * .pi))
        let count = CGFloat(max(stroke.count - 1, 1))
        return stroke.enumerated().map { index, point in
            let dx = (point.x - centroid.x) * size
            let dy = (point.y - centroid.y) * size
            let t = CGFloat(index) / count
            return CGPoint(
                x: centroid.x + dx * cos(angle) - dy * sin(angle) + offset.dx
                    + wobble * sin(2 * .pi * frequency * t + phase.dx) + rng.uniform(-0.6, 0.6),
                y: centroid.y + dx * sin(angle) + dy * cos(angle) + offset.dy
                    + wobble * sin(2 * .pi * frequency * t + phase.dy) + rng.uniform(-0.6, 0.6)
            )
        }
    }

    static func mistaken(
        _ mistake: CorpusMistake,
        target: Int,
        user: [[CGPoint]],
        substitutes: [Int],
        rng: inout SeededGenerator
    ) -> [CGPoint]? {
        let stroke = user[target]
        switch mistake {
        case .substituted:
            guard !substitutes.isEmpty else {
                return nil
            }
            let other = substitutes[rng.index(below: substitutes.count)]
            let from = ProcrustesNormalizer.centroid(of: user[other])
            let to = ProcrustesNormalizer.centroid(of: stroke)
            return user[other].map { CGPoint(x: $0.x - from.x + to.x, y: $0.y - from.y + to.y) }
        case .reversed:
            return stroke.reversed()
        case .truncated:
            let resampled = PointSampler.sample(points: stroke, count: denseSampleCount)
            let kept = max(2, Int((CGFloat(resampled.count - 1) * truncatedFraction).rounded()) + 1)
            return Array(resampled.prefix(kept))
        case .shifted:
            let distance = shiftFraction * canvasSize.width
            let centroid = ProcrustesNormalizer.centroid(of: stroke)
            let start = rng.index(below: 8)
            for step in 0..<8 {
                let angle = CGFloat((start + step) % 8) * .pi / 4
                let moved = CGPoint(x: centroid.x + distance * cos(angle), y: centroid.y + distance * sin(angle))
                if moved.x > 10, moved.x < canvasSize.width - 10, moved.y > 10, moved.y < canvasSize.height - 10 {
                    return stroke.map { CGPoint(x: $0.x + distance * cos(angle), y: $0.y + distance * sin(angle)) }
                }
            }
            return nil
        }
    }

    private static func shapeDistance(_ lhs: [CGPoint], _ rhs: [CGPoint]) -> CGFloat {
        let (normalizedLhs, normalizedRhs) = ProcrustesNormalizer.normalize(source: lhs, target: rhs, applyRotation: false)
        return FrechetDistance.compute(between: normalizedLhs.points, and: normalizedRhs.points)
    }

    private static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func fit(_ lower: CGFloat, _ upper: CGFloat, upper limit: CGFloat, margin: CGFloat) -> CGFloat {
        if lower < margin {
            return margin - lower
        }
        if upper > limit - margin {
            return limit - margin - upper
        }
        return 0
    }

    static func describe(
        title: String,
        characters: [CorpusCharacter],
        reports: [(label: String, strictness: GradingStrictness, report: CorpusReport)]
    ) -> String {
        let strokes = characters.reduce(0) { $0 + $1.strokes.count }
        var lines = ["\(title): \(characters.count) characters, \(strokes) reference strokes"]
        lines.append("  false rejects of correct strokes (rejected/judged), characters with any reject")
        for entry in reports {
            for scale in correctScales {
                let strokes = entry.report.falseRejects[scale] ?? CorpusTally()
                let characters = entry.report.rejectedCharacters[scale] ?? CorpusTally()
                let columns = [
                    pad(entry.label, 18), pad(entry.strictness.rawValue, 8),
                    pad(String(format: "%.2fx", scale), 6),
                    "strokes " + strokes.formatted, "  chars " + characters.formatted,
                ]
                lines.append("    " + columns.joined())
            }
        }
        lines.append("  false accepts of incorrect strokes (accepted/judged)")
        for entry in reports {
            for mistake in CorpusMistake.allCases {
                let tally = entry.report.falseAccepts[mistake] ?? CorpusTally()
                let columns = [
                    pad(entry.label, 18), pad(entry.strictness.rawValue, 8), pad(mistake.rawValue, 12), tally.formatted,
                ]
                lines.append("    " + columns.joined())
            }
            let columns = [
                pad(entry.label, 18), pad(entry.strictness.rawValue, 8), pad("all", 12),
                entry.report.totalFalseAccepts.formatted,
            ]
            lines.append("    " + columns.joined())
        }
        lines.append("  correct strokes rejected by prior anchors (0 / 1 / 2+), correct strokes failing proportion")
        for entry in reports {
            let buckets = (0...2).map { String(entry.report.falseRejectsByAnchorCount[$0] ?? 0) }
            let columns = [
                pad(entry.label, 18), pad(entry.strictness.rawValue, 8),
                pad(buckets.joined(separator: " / "), 18), entry.report.disproportionateCorrectStrokes.formatted,
            ]
            lines.append("    " + columns.joined())
        }
        return lines.joined(separator: "\n")
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.padding(toLength: max(width, text.count), withPad: " ", startingAt: 0)
    }
}
