import CoreGraphics
import SVGPath

/// Configuration for stroke validation thresholds.
struct ValidationConfig: Sendable {
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

    static let standard = ValidationConfig()
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
        let userSampled = PointSampler.sample(points: userPoints, count: config.sampleCount)
        let userCentroid = ProcrustesNormalizer.centroid(of: userSampled)

        let canvasDiagonal = sqrt(
            canvasSize.width * canvasSize.width + canvasSize.height * canvasSize.height
        )
        let centroidMaxDist = canvasDiagonal * config.centroidTolerance * config.leniency
        let placement = anchors.map { placementOffset(anchors: $0, referenceSamples: referenceSamples, canvasSize: canvasSize) }
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
            let refPoints = shifted(referenceSamples[idx], by: placement ?? .zero)

            let refCentroid = ProcrustesNormalizer.centroid(of: refPoints)

            let centroidDist = hypot(userCentroid.x - refCentroid.x, userCentroid.y - refCentroid.y)

            if centroidDist > centroidMaxDist {
                continue
            }

            let result = compareStrokes(
                userPoints: userSampled,
                referencePoints: refPoints,
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
        return result
    }

    static func placementOffset(
        anchors: [StrokeAnchor],
        referenceSamples: [[CGPoint]],
        canvasSize: CGSize
    ) -> CGVector {
        let offsets = anchors.compactMap { anchor -> CGVector? in
            guard referenceSamples.indices.contains(anchor.referenceIndex),
                  !referenceSamples[anchor.referenceIndex].isEmpty else {
                return nil
            }
            let refCentroid = ProcrustesNormalizer.centroid(of: referenceSamples[anchor.referenceIndex])
            return CGVector(dx: anchor.userCentroid.x - refCentroid.x, dy: anchor.userCentroid.y - refCentroid.y)
        }
        guard !offsets.isEmpty else { return .zero }
        let count = CGFloat(offsets.count)
        let mean = CGVector(
            dx: offsets.map(\.dx).reduce(0, +) / count,
            dy: offsets.map(\.dy).reduce(0, +) / count
        )
        let points = referenceSamples.flatMap { $0 }
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else {
            return mean
        }
        return CGVector(
            dx: clamp(mean.dx, lower: -minX, upper: canvasSize.width - maxX),
            dy: clamp(mean.dy, lower: -minY, upper: canvasSize.height - maxY)
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard lower <= upper else { return 0 }
        return min(max(value, lower), upper)
    }

    private static func shifted(_ points: [CGPoint], by offset: CGVector) -> [CGPoint] {
        guard offset != .zero else { return points }
        return points.map { CGPoint(x: $0.x + offset.dx, y: $0.y + offset.dy) }
    }

    // MARK: - Private

    private static func compareStrokes(
        userPoints: [CGPoint],
        referencePoints: [CGPoint],
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
        let accepted = shapePassed && positionPassed

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

        return StrokeValidationResult(
            score: score,
            accepted: accepted,
            matchedStrokeIndex: matchedIndex,
            correctOrder: correctOrder,
            frechetDistance: frechet
        )
    }
}
