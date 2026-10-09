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
    /// remove the last-drawn acceptance — in freeDraw, strokes are accepted
    /// out of order, so this is not `matchedStrokeIndices.max()`.
    private(set) var acceptanceOrder: [Int] = []
    @Published private(set) var attemptCount: Int = 0
    @Published private(set) var consecutiveMisses: Int = 0
    @Published private(set) var isComplete: Bool = false
    @Published var mode: PracticeMode
    @Published private(set) var isRevealed: Bool = false
    @Published private(set) var isCueAvailable: Bool = true
    private(set) var isExposed: Bool

    let kanjiData: KanjiData
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

    var hidesAnswer: Bool {
        mode.hidesAnswer && isCueAvailable && !isRevealed
    }

    var shouldShowAutoHint: Bool {
        guard let threshold = mode.autoHintAfterMisses else { return false }
        return consecutiveMisses >= threshold
    }

    init(kanjiData: KanjiData, mode: PracticeMode = .trace, config: ValidationConfig = .standard) {
        self.kanjiData = kanjiData
        self.mode = mode
        self.validationConfig = config
        self.isExposed = !mode.hidesAnswer
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

        let orderOk = result.correctOrder || mode == .freeDraw
        if result.accepted, let matchedIndex = result.matchedStrokeIndex, orderOk {
            matchedStrokeIndices.insert(matchedIndex)
            acceptanceOrder.append(matchedIndex)
            consecutiveMisses = 0
            currentStrokeIndex = matchedIndex + 1

            if matchedStrokeIndices.count == totalStrokes {
                isComplete = true
                recordRunCompletion()
            }

            phase = .strokeAccepted(strokeIndex: matchedIndex)
        } else {
            attemptCount += 1
            consecutiveMisses += 1
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
        currentStrokeIndex = lastDrawn
        isComplete = false
        phase = .waitingForInput
        return lastDrawn
    }

    func reset() {
        phase = .waitingForInput
        currentStrokeIndex = 0
        matchedStrokeIndices = []
        acceptanceOrder = []
        attemptCount = 0
        consecutiveMisses = 0
        isComplete = false
        runStartedAt = nil
        runRecorded = false
    }

    func revealAnswer() {
        isRevealed = true
    }

    func markCueUnavailable() {
        isCueAvailable = false
        isExposed = true
    }

    func changeMode(_ newMode: PracticeMode) {
        mode = newMode
        if !newMode.hidesAnswer {
            isExposed = true
        }
        reset()
    }

    private func recordRunCompletion() {
        guard !runRecorded else { return }
        runRecorded = true
        let completedAt = now()
        let record = PracticeRecord(
            id: UUID(),
            codePoint: kanjiData.codePoint,
            mode: mode.rawValue,
            revealed: isRevealed,
            exposed: isExposed,
            misses: attemptCount,
            startedAt: runStartedAt ?? completedAt,
            completedAt: completedAt,
            leniency: Double(validationConfig.leniency)
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
