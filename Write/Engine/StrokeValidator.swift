import CoreGraphics
import SVGPath

/// Configuration for stroke validation thresholds.
struct ValidationConfig: Equatable, Sendable {
    /// Overall leniency multiplier. Higher = more forgiving.
    var leniency: CGFloat = 1.0

    /// Maximum normalized Frechet distance for a stroke to be considered matching.
    /// Strokes above this threshold are rejected.
    var shapeThreshold: CGFloat = 0.42

    /// Maximum centroid distance (as fraction of canvas diagonal) for fast rejection.
    var centroidTolerance: CGFloat = 0.35

    /// Maximum centroid distance (as fraction of canvas diagonal) for position acceptance.
    /// Tighter than centroidTolerance — strokes must be near the correct location.
    var positionTolerance: CGFloat = 0.03

    var guidelessFirstStrokeTolerance: CGFloat = 0.10

    var guidelessPositionTolerance: CGFloat = 0.07

    /// Number of sample points for comparison.
    var sampleCount: Int = 50

    var fitsScale = true

    var minimumScale: CGFloat = 0.6

    var maximumScale: CGFloat = 1.6

    var scaleSpreadFloor: CGFloat = 0.04

    var scaleSpreadForFullConfidence: CGFloat = 0.10

    var scaleAnchorsForFullConfidence = 3

    var enforcesProportion = true

    var proportionTolerance: CGFloat = 1.6

    var proportionMinimumReferenceExtent: CGFloat = 0.03

    var proportionMinimumAnchors = 2

    var boundaryTolerance: CGFloat = 0.02

    var rejectsDisproportion: Bool {
        enforcesProportion && leniency <= GradingStrictness.strict.leniency + 0.001
    }

    static let translationOnly = ValidationConfig(fitsScale: false, enforcesProportion: false)

    static let standard = ValidationConfig()

    static let gradingVersion = 3
}

/// Result of validating a single user stroke against a reference.
struct StrokeValidationResult: Sendable {
    /// Similarity score from 0 (no match) to 1 (perfect match).
    let score: CGFloat

    /// Whether the stroke passes the configured threshold.
    let accepted: Bool

    /// Index of the matched reference stroke (if any).
    let matchedStrokeIndex: Int?

    /// Whether the matched stroke was the expected next in sequence.
    let correctOrder: Bool

    /// Raw Frechet distance (normalized).
    let frechetDistance: CGFloat

    var userCentroid: CGPoint?

    var evidence: StrokeEvidence = .notEvaluated

    var anchor: StrokeAnchor?

    var geometryAccepted: Bool?
}

extension StrokeValidationResult {
    var passedGeometry: Bool {
        (geometryAccepted ?? accepted) && matchedStrokeIndex != nil
    }

    var wrongOrderCandidate: Int? {
        guard passedGeometry, !correctOrder else {
            return nil
        }
        return matchedStrokeIndex
    }

    var failedBoundary: Bool {
        evidence.boundaryPassed == false
    }
}

/// Orchestrates the stroke validation pipeline: sample -> normalize -> compare -> score.
enum StrokeValidator {

    /// Validates a user-drawn stroke against a specific reference stroke.
    static func validate(
        userPoints: [CGPoint],
        referencePathData: String,
        canvasSize: CGSize,
        config: ValidationConfig = .standard
    ) -> StrokeValidationResult? {
        guard let referencePath = try? StrokeRenderer.createPath(from: referencePathData) else {
            return nil
        }

        var transform = StrokeRenderer.scaleTransform(to: canvasSize)
        guard let scaledPath = referencePath.copy(using: &transform) else {
            return nil
        }

        let refPoints = PointSampler.sample(path: scaledPath, count: config.sampleCount)
        let userSampled = PointSampler.sample(points: userPoints, count: config.sampleCount)

        return compareStrokes(
            userPoints: userSampled,
            referencePoints: refPoints,
            referenceExtent: extent(of: refPoints),
            proportionScale: 1,
            rejectsDisproportion: false,
            canvasSize: canvasSize,
            config: config,
            positionTolerance: config.positionTolerance,
            matchedIndex: nil,
            expectedIndex: nil
        )
    }

    /// Parses, scales and samples every reference stroke for a canvas size.
    /// The result can be cached by the caller and fed to the
    /// `identifyStroke(userPoints:referenceSamples:...)` overload, avoiding an
    /// SVG parse of every unmatched stroke on each completed user stroke.
    /// Strokes that fail to parse yield an empty array.
    static func sampleReferenceStrokes(
        _ strokes: [KanjiStroke],
        canvasSize: CGSize,
        sampleCount: Int
    ) -> [[CGPoint]] {
        var transform = StrokeRenderer.scaleTransform(to: canvasSize)
        return strokes.map { stroke in
            guard let path = try? StrokeRenderer.createPath(from: stroke.pathData),
                  let scaled = path.copy(using: &transform) else {
                return []
            }
            return PointSampler.sample(path: scaled, count: sampleCount)
        }
    }

    /// Given a user stroke, finds the best match among unmatched reference strokes.
    static func identifyStroke(
        userPoints: [CGPoint],
        referenceStrokes: [KanjiStroke],
        unmatchedIndices: Set<Int>,
        canvasSize: CGSize,
        expectedStrokeIndex: Int,
        config: ValidationConfig = .standard
    ) -> StrokeValidationResult {
        identifyStroke(
            userPoints: userPoints,
            referenceSamples: sampleReferenceStrokes(
                referenceStrokes, canvasSize: canvasSize, sampleCount: config.sampleCount
            ),
            unmatchedIndices: unmatchedIndices,
            canvasSize: canvasSize,
            expectedStrokeIndex: expectedStrokeIndex,
            config: config
        )
    }

    /// Overload taking reference samples precomputed by `sampleReferenceStrokes`.
    static func identifyStroke(
        userPoints: [CGPoint],
        referenceSamples: [[CGPoint]],
        unmatchedIndices: Set<Int>,
        canvasSize: CGSize,
        expectedStrokeIndex: Int,
        anchors: [StrokeAnchor]? = nil,
        config: ValidationConfig = .standard
    ) -> StrokeValidationResult {
        let insideBox = StrokeBoundary.excursion(of: userPoints, canvasSize: canvasSize)
            .map { $0 <= config.boundaryTolerance } ?? false
        let userSampled = PointSampler.sample(points: userPoints, count: config.sampleCount)
        let userCentroid = ProcrustesNormalizer.centroid(of: userSampled)

        let canvasDiagonal = sqrt(
            canvasSize.width * canvasSize.width + canvasSize.height * canvasSize.height
        )
        let centroidMaxDist = canvasDiagonal * config.centroidTolerance * config.leniency
        let placement = anchors.map {
            self.placement(anchors: $0, referenceSamples: referenceSamples, canvasSize: canvasSize, config: config)
        } ?? .identity
        let proportionScale: CGFloat?
        if let anchors {
            proportionScale = self.proportionScale(
                anchors: anchors, referenceSamples: referenceSamples, canvasSize: canvasSize, config: config
            )
        } else {
            proportionScale = 1
        }
        let positionTolerance: CGFloat
        if let anchors {
            positionTolerance = anchors.isEmpty
                ? config.guidelessFirstStrokeTolerance
                : config.guidelessPositionTolerance
        } else {
            positionTolerance = config.positionTolerance
        }

        var bestResult: StrokeValidationResult?

        for idx in unmatchedIndices.sorted() {
            guard referenceSamples.indices.contains(idx) else { continue }
            guard !referenceSamples[idx].isEmpty else { continue }
            let refPoints = transformed(referenceSamples[idx], by: placement)

            let refCentroid = ProcrustesNormalizer.centroid(of: refPoints)

            let centroidDist = hypot(userCentroid.x - refCentroid.x, userCentroid.y - refCentroid.y)

            if centroidDist > centroidMaxDist {
                continue
            }

            let result = compareStrokes(
                userPoints: userSampled,
                referencePoints: refPoints,
                referenceExtent: extent(of: referenceSamples[idx]),
                proportionScale: proportionScale,
                rejectsDisproportion: anchors != nil && config.rejectsDisproportion,
                canvasSize: canvasSize,
                config: config,
                positionTolerance: positionTolerance,
                matchedIndex: idx,
                expectedIndex: expectedStrokeIndex
            )

            if result.accepted && result.correctOrder {
                bestResult = result
                break
            }
            if let best = bestResult {
                if result.score > best.score {
                    bestResult = result
                }
            } else {
                bestResult = result
            }
        }

        var result = bestResult ?? StrokeValidationResult(
            score: 0,
            accepted: false,
            matchedStrokeIndex: nil,
            correctOrder: false,
            frechetDistance: .infinity
        )
        result.userCentroid = userCentroid
        if let matched = result.matchedStrokeIndex {
            result.anchor = StrokeAnchor(
                referenceIndex: matched,
                userCentroid: userCentroid,
                userExtent: extent(of: userSampled)
            )
        }
        result.evidence.boundaryPassed = insideBox
        return StrokeValidationResult(
            score: result.score,
            accepted: result.accepted && insideBox,
            matchedStrokeIndex: result.matchedStrokeIndex,
            correctOrder: result.correctOrder,
            frechetDistance: result.frechetDistance,
            userCentroid: result.userCentroid,
            evidence: result.evidence,
            anchor: result.anchor,
            geometryAccepted: result.accepted
        )
    }

    static func placement(
        anchors: [StrokeAnchor],
        referenceSamples: [[CGPoint]],
        canvasSize: CGSize
    ) -> StrokePlacement {
        placement(anchors: anchors, referenceSamples: referenceSamples, canvasSize: canvasSize, config: .standard)
    }

    static func placement(
        anchors: [StrokeAnchor],
        referenceSamples: [[CGPoint]],
        canvasSize: CGSize,
        config: ValidationConfig
    ) -> StrokePlacement {
        let pairs = anchors.compactMap { anchor -> (reference: CGPoint, user: CGPoint)? in
            guard referenceSamples.indices.contains(anchor.referenceIndex),
                  !referenceSamples[anchor.referenceIndex].isEmpty else {
                return nil
            }
            let refCentroid = ProcrustesNormalizer.centroid(of: referenceSamples[anchor.referenceIndex])
            return (refCentroid, anchor.userCentroid)
        }
        guard !pairs.isEmpty else {
            return .identity
        }
        let referenceMean = ProcrustesNormalizer.centroid(of: pairs.map(\.reference))
        let userMean = ProcrustesNormalizer.centroid(of: pairs.map(\.user))
        let points = referenceSamples.flatMap { $0 }
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else {
            return StrokePlacement(
                scale: 1,
                offset: CGVector(dx: userMean.x - referenceMean.x, dy: userMean.y - referenceMean.y)
            )
        }

        var scale: CGFloat = 1
        if config.fitsScale {
            scale = fittedScale(pairs: pairs, canvasSize: canvasSize, config: config)
            let fittingScale = min(
                (maxX - minX) > 0 ? canvasSize.width / (maxX - minX) : scale,
                (maxY - minY) > 0 ? canvasSize.height / (maxY - minY) : scale
            )
            scale = min(scale, fittingScale)
        }

        let offset = CGVector(
            dx: userMean.x - scale * referenceMean.x,
            dy: userMean.y - scale * referenceMean.y
        )
        return StrokePlacement(
            scale: scale,
            offset: CGVector(
                dx: clamp(offset.dx, lower: -scale * minX, upper: canvasSize.width - scale * maxX),
                dy: clamp(offset.dy, lower: -scale * minY, upper: canvasSize.height - scale * maxY)
            )
        )
    }

    static func placementOffset(
        anchors: [StrokeAnchor],
        referenceSamples: [[CGPoint]],
        canvasSize: CGSize
    ) -> CGVector {
        placement(
            anchors: anchors,
            referenceSamples: referenceSamples,
            canvasSize: canvasSize,
            config: .translationOnly
        ).offset
    }

    static func proportionScale(
        anchors: [StrokeAnchor],
        referenceSamples: [[CGPoint]],
        canvasSize: CGSize,
        config: ValidationConfig
    ) -> CGFloat? {
        let minimumExtent = config.proportionMinimumReferenceExtent * min(canvasSize.width, canvasSize.height)
        let ratios = anchors.compactMap { anchor -> CGFloat? in
            guard anchor.userExtent > 0,
                  referenceSamples.indices.contains(anchor.referenceIndex) else {
                return nil
            }
            let referenceExtent = extent(of: referenceSamples[anchor.referenceIndex])
            guard referenceExtent >= minimumExtent else {
                return nil
            }
            return anchor.userExtent / referenceExtent
        }.sorted()
        guard !ratios.isEmpty, ratios.count >= config.proportionMinimumAnchors else {
            return nil
        }
        let middle = ratios.count / 2
        if ratios.count % 2 == 0 {
            return (ratios[middle - 1] + ratios[middle]) / 2
        }
        return ratios[middle]
    }

    static func extent(of points: [CGPoint]) -> CGFloat {
        ProcrustesNormalizer.rmsSize(of: ProcrustesNormalizer.translateToOrigin(points))
    }

    private static func fittedScale(
        pairs: [(reference: CGPoint, user: CGPoint)],
        canvasSize: CGSize,
        config: ValidationConfig
    ) -> CGFloat {
        guard pairs.count >= 2 else {
            return 1
        }
        let referenceMean = ProcrustesNormalizer.centroid(of: pairs.map(\.reference))
        let userMean = ProcrustesNormalizer.centroid(of: pairs.map(\.user))
        var covariance: CGFloat = 0
        var variance: CGFloat = 0
        for pair in pairs {
            let dr = CGVector(dx: pair.reference.x - referenceMean.x, dy: pair.reference.y - referenceMean.y)
            let du = CGVector(dx: pair.user.x - userMean.x, dy: pair.user.y - userMean.y)
            covariance += dr.dx * du.dx + dr.dy * du.dy
            variance += dr.dx * dr.dx + dr.dy * dr.dy
        }
        let canvasDiagonal = hypot(canvasSize.width, canvasSize.height)
        guard variance > 0, canvasDiagonal > 0 else {
            return 1
        }
        let spread = sqrt(variance / CGFloat(pairs.count)) / canvasDiagonal
        guard spread > config.scaleSpreadFloor else {
            return 1
        }
        let raw = min(max(covariance / variance, config.minimumScale), config.maximumScale)
        let spreadRange = max(config.scaleSpreadForFullConfidence - config.scaleSpreadFloor, .ulpOfOne)
        let spreadConfidence = min(1, (spread - config.scaleSpreadFloor) / spreadRange)
        let countRange = CGFloat(max(config.scaleAnchorsForFullConfidence - 1, 1))
        let countConfidence = min(1, CGFloat(pairs.count - 1) / countRange)
        return 1 + spreadConfidence * countConfidence * (raw - 1)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard lower <= upper else {
            return (lower + upper) / 2
        }
        return min(max(value, lower), upper)
    }

    private static func transformed(_ points: [CGPoint], by placement: StrokePlacement) -> [CGPoint] {
        guard placement != .identity else {
            return points
        }
        return points.map { placement.apply(to: $0) }
    }

    // MARK: - Private

    private static func compareStrokes(
        userPoints: [CGPoint],
        referencePoints: [CGPoint],
        referenceExtent: CGFloat,
        proportionScale: CGFloat?,
        rejectsDisproportion: Bool,
        canvasSize: CGSize,
        config: ValidationConfig,
        positionTolerance: CGFloat,
        matchedIndex: Int?,
        expectedIndex: Int?
    ) -> StrokeValidationResult {
        // Position check: centroid distance in canvas space
        let userCentroid = ProcrustesNormalizer.centroid(of: userPoints)
        let refCentroid = ProcrustesNormalizer.centroid(of: referencePoints)
        let centroidDist = hypot(userCentroid.x - refCentroid.x, userCentroid.y - refCentroid.y)
        let canvasDiagonal = hypot(canvasSize.width, canvasSize.height)
        let normalizedPosition = centroidDist / canvasDiagonal
        let positionThreshold = positionTolerance * config.leniency
        let positionPassed = normalizedPosition <= positionThreshold

        // Shape check: Procrustes normalize then Frechet distance
        let (normUser, normRef) = ProcrustesNormalizer.normalize(
            source: userPoints,
            target: referencePoints,
            applyRotation: false
        )

        let frechet = FrechetDistance.compute(
            between: normUser.points,
            and: normRef.points
        )

        let shapeThreshold = config.shapeThreshold * config.leniency
        let shapePassed = frechet <= shapeThreshold
        let proportionPassed = proportionCheck(
            userExtent: normUser.scale,
            referenceExtent: referenceExtent,
            proportionScale: proportionScale,
            canvasSize: canvasSize,
            config: config
        )
        let proportionRejects = rejectsDisproportion && proportionPassed == false
        let accepted = shapePassed && positionPassed && !proportionRejects

        let shapeScore: CGFloat
        if frechet <= 0 {
            shapeScore = 1.0
        } else if frechet >= shapeThreshold * 2 {
            shapeScore = 0.0
        } else {
            shapeScore = max(0, 1.0 - frechet / (shapeThreshold * 2))
        }

        let positionFactor = max(0, 1.0 - normalizedPosition / (positionThreshold * 2))
        let score = shapeScore * positionFactor

        let correctOrder: Bool
        if let matched = matchedIndex, let expected = expectedIndex {
            correctOrder = matched == expected
        } else {
            correctOrder = true
        }

        var result = StrokeValidationResult(
            score: score,
            accepted: accepted,
            matchedStrokeIndex: matchedIndex,
            correctOrder: correctOrder,
            frechetDistance: frechet
        )
        result.evidence = StrokeEvidence(
            shapePassed: shapePassed,
            positionPassed: positionPassed,
            proportionPassed: proportionPassed
        )
        return result
    }

    private static func proportionCheck(
        userExtent: CGFloat,
        referenceExtent: CGFloat,
        proportionScale: CGFloat?,
        canvasSize: CGSize,
        config: ValidationConfig
    ) -> Bool? {
        let minimumExtent = config.proportionMinimumReferenceExtent * min(canvasSize.width, canvasSize.height)
        guard let proportionScale, proportionScale > 0, referenceExtent >= minimumExtent else {
            return nil
        }
        let ratio = userExtent / (referenceExtent * proportionScale)
        return ratio >= 1 / config.proportionTolerance && ratio <= config.proportionTolerance
    }
}
