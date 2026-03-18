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
            matchedIndex: nil,
            expectedIndex: nil
        )
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
        let userSampled = PointSampler.sample(points: userPoints, count: config.sampleCount)
        let userCentroid = ProcrustesNormalizer.centroid(of: userSampled)

        let canvasDiagonal = sqrt(
            canvasSize.width * canvasSize.width + canvasSize.height * canvasSize.height
        )
        let centroidMaxDist = canvasDiagonal * config.centroidTolerance * config.leniency

        var bestResult: StrokeValidationResult?

        for idx in unmatchedIndices.sorted() {
            guard let refPath = try? StrokeRenderer.createPath(from: referenceStrokes[idx].pathData) else {
                continue
            }

            var transform = StrokeRenderer.scaleTransform(to: canvasSize)
            guard let scaledPath = refPath.copy(using: &transform) else { continue }

            let refPoints = PointSampler.sample(path: scaledPath, count: config.sampleCount)
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
                matchedIndex: idx,
                expectedIndex: expectedStrokeIndex
            )

            if let best = bestResult {
                if result.score > best.score {
                    bestResult = result
                }
            } else {
                bestResult = result
            }
        }

        return bestResult ?? StrokeValidationResult(
            score: 0,
            accepted: false,
            matchedStrokeIndex: nil,
            correctOrder: false,
            frechetDistance: .infinity
        )
    }

    // MARK: - Private

    private static func compareStrokes(
        userPoints: [CGPoint],
        referencePoints: [CGPoint],
        canvasSize: CGSize,
        config: ValidationConfig,
        matchedIndex: Int?,
        expectedIndex: Int?
    ) -> StrokeValidationResult {
        // Position check: centroid distance in canvas space
        let userCentroid = ProcrustesNormalizer.centroid(of: userPoints)
        let refCentroid = ProcrustesNormalizer.centroid(of: referencePoints)
        let centroidDist = hypot(userCentroid.x - refCentroid.x, userCentroid.y - refCentroid.y)
        let canvasDiagonal = hypot(canvasSize.width, canvasSize.height)
        let normalizedPosition = centroidDist / canvasDiagonal
        let positionThreshold = config.positionTolerance * config.leniency
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
