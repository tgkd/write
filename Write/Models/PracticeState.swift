import Combine
import CoreGraphics
import Foundation

@MainActor
final class PracticeState: ObservableObject {

    enum Phase: Equatable {
        case waitingForInput
        case userDrawing
        case validating
        case strokeAccepted(strokeIndex: Int)
        case strokeRejected
    }

    @Published private(set) var phase: Phase = .waitingForInput
    @Published private(set) var currentStrokeIndex: Int = 0
    @Published private(set) var matchedStrokeIndices: Set<Int> = []

    /// Matched reference indices in the order the user drew them. Undo must
    /// remove the last-drawn acceptance, not `matchedStrokeIndices.max()`.
    private(set) var acceptanceOrder: [Int] = []
    private(set) var anchors: [StrokeAnchor] = []
    @Published private(set) var attemptCount: Int = 0
    @Published private(set) var consecutiveMisses: Int = 0
    @Published private(set) var isComplete: Bool = false
    @Published private(set) var mode: PracticeMode
    @Published private(set) var hint: RecallHint = .unused
    @Published private(set) var lastRejection: StrokeRejection?
    @Published private(set) var missEvidence = MissEvidence()
    @Published private var isLastRejectionDisputed = false

    let kanjiData: KanjiData
    let isRecall: Bool
    let firstStrokeStart: CGPoint?
    var validationConfig: ValidationConfig
    var now: () -> Date = Date.init
    var onRunCompleted: ((PracticeRecord) -> Void)?

    private var runStartedAt: Date?
    private var runRecorded = false

    private var referenceSampleCache: (canvasSize: CGSize, sampleCount: Int, samples: [[CGPoint]])?

    var totalStrokes: Int { kanjiData.strokes.count }

    var unmatchedIndices: Set<Int> {
        Set(kanjiData.strokes.indices).subtracting(matchedStrokeIndices)
    }

    var hidesCharacter: Bool {
        isRecall && hint < .character
    }

    var hidesGuide: Bool {
        isRecall && hint < .strokes
    }

    var usesRelativePlacement: Bool {
        isRecall || mode == .copy
    }

    var startMarker: CGPoint? {
        guard usesRelativePlacement, mode == .copy || hidesGuide, matchedStrokeIndices.isEmpty else {
            return nil
        }
        return firstStrokeStart
    }

    var nextHint: RecallHint? {
        isRecall ? hint.next : nil
    }

    var shouldShowAutoHint: Bool {
        guard let threshold = mode.autoHintAfterMisses else { return false }
        return consecutiveMisses >= threshold
    }

    init(kanjiData: KanjiData, mode: PracticeMode = .trace, isRecall: Bool = false, config: ValidationConfig = .standard) {
        self.kanjiData = kanjiData
        self.isRecall = isRecall
        self.mode = isRecall ? .strokeByStroke : mode
        self.validationConfig = config
        self.firstStrokeStart = kanjiData.strokes.first
            .flatMap { try? StrokeRenderer.createPath(from: $0.pathData) }
            .flatMap { PointSampler.sample(path: $0, count: 2).first }
    }

    func beginDrawing() {
        guard phase == .waitingForInput else { return }
        phase = .userDrawing
    }

    func beginValidation() {
        guard phase == .userDrawing else { return }
        phase = .validating
    }

    func processValidationResult(_ result: StrokeValidationResult) {
        guard phase == .validating else { return }

        if runStartedAt == nil {
            runStartedAt = now()
        }

        if result.accepted, let matchedIndex = result.matchedStrokeIndex, result.correctOrder {
            matchedStrokeIndices.insert(matchedIndex)
            acceptanceOrder.append(matchedIndex)
            if let anchor = result.anchor {
                anchors.append(anchor)
            }
            consecutiveMisses = 0
            lastRejection = nil
            currentStrokeIndex = matchedIndex + 1

            if matchedStrokeIndices.count == totalStrokes {
                isComplete = true
                recordRunCompletion()
            }

            phase = .strokeAccepted(strokeIndex: matchedIndex)
        } else {
            attemptCount += 1
            consecutiveMisses += 1
            missEvidence.record(result)
            lastRejection = rejection(for: result)
            isLastRejectionDisputed = false
            phase = .strokeRejected
        }
    }

    func acknowledgeResult() {
        switch phase {
        case .strokeAccepted, .strokeRejected:
            phase = .waitingForInput
        default:
            break
        }
    }

    func undoLastStroke() -> Int? {
        guard let lastDrawn = acceptanceOrder.popLast() else { return nil }
        matchedStrokeIndices.remove(lastDrawn)
        anchors.removeAll { $0.referenceIndex == lastDrawn }
        currentStrokeIndex = lastDrawn
        isComplete = false
        lastRejection = nil
        phase = .waitingForInput
        return lastDrawn
    }

    func reset() {
        phase = .waitingForInput
        currentStrokeIndex = 0
        matchedStrokeIndices = []
        acceptanceOrder = []
        anchors = []
        attemptCount = 0
        consecutiveMisses = 0
        isComplete = false
        lastRejection = nil
        isLastRejectionDisputed = false
        missEvidence = MissEvidence()
        runStartedAt = nil
        runRecorded = false
    }

    private func rejection(for result: StrokeValidationResult) -> StrokeRejection {
        if result.failedBoundary {
            return .outOfFrame
        }
        if let drawn = result.wrongOrderCandidate {
            return .wrongOrder(drawnStroke: drawn, expectedStroke: currentStrokeIndex)
        }
        return .shape
    }

    var canDisputeLastRejection: Bool {
        lastRejection != nil && !isComplete && !isLastRejectionDisputed
    }

    func disputeLastRejection() {
        guard canDisputeLastRejection else {
            return
        }
        missEvidence.disputed += 1
        isLastRejectionDisputed = true
    }

    func showNextHint() {
        guard let next = nextHint else { return }
        hint = next
    }

    func changeMode(_ newMode: PracticeMode) {
        guard !isRecall else { return }
        mode = newMode
        reset()
    }

    private func recordRunCompletion() {
        guard !runRecorded else { return }
        runRecorded = true
        let completedAt = now()
        let record = PracticeRecord(
            id: UUID(),
            codePoint: kanjiData.codePoint,
            mode: isRecall ? PracticeRecord.recallMode : mode.rawValue,
            revealed: hint != .unused,
            exposed: !isRecall,
            misses: attemptCount,
            startedAt: runStartedAt ?? completedAt,
            completedAt: completedAt,
            leniency: Double(validationConfig.leniency),
            strictness: GradingStrictness.nearest(toLeniency: validationConfig.leniency).rawValue,
            gradingVersion: ValidationConfig.gradingVersion,
            evidence: missEvidence
        )
        onRunCompleted?(record)
    }

    /// Reference strokes parsed/scaled/sampled for a canvas size, cached so
    /// validation doesn't re-parse every stroke's SVG on each attempt.
    func referenceSamples(canvasSize: CGSize) -> [[CGPoint]] {
        let sampleCount = validationConfig.sampleCount
        if let cache = referenceSampleCache,
           cache.canvasSize == canvasSize, cache.sampleCount == sampleCount {
            return cache.samples
        }
        let samples = StrokeValidator.sampleReferenceStrokes(
            kanjiData.strokes, canvasSize: canvasSize, sampleCount: sampleCount
        )
        referenceSampleCache = (canvasSize, sampleCount, samples)
        return samples
    }

    func prewarmReferenceSamples(canvasSize: CGSize) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        _ = referenceSamples(canvasSize: canvasSize)
    }
}
