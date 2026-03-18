import Combine
import CoreGraphics

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
    @Published private(set) var attemptCount: Int = 0
    @Published private(set) var consecutiveMisses: Int = 0
    @Published private(set) var isComplete: Bool = false
    @Published var mode: PracticeMode

    let kanjiData: KanjiData
    var validationConfig: ValidationConfig

    var totalStrokes: Int { kanjiData.strokes.count }

    var unmatchedIndices: Set<Int> {
        Set(kanjiData.strokes.indices).subtracting(matchedStrokeIndices)
    }

    var shouldShowAutoHint: Bool {
        guard let threshold = mode.autoHintAfterMisses else { return false }
        return consecutiveMisses >= threshold
    }

    init(kanjiData: KanjiData, mode: PracticeMode = .trace, config: ValidationConfig = .standard) {
        self.kanjiData = kanjiData
        self.mode = mode
        self.validationConfig = config
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

        let orderOk = result.correctOrder || mode == .freeDraw
        if result.accepted, let matchedIndex = result.matchedStrokeIndex, orderOk {
            matchedStrokeIndices.insert(matchedIndex)
            consecutiveMisses = 0
            currentStrokeIndex = matchedIndex + 1

            if matchedStrokeIndices.count == totalStrokes {
                isComplete = true
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

    func reset() {
        phase = .waitingForInput
        currentStrokeIndex = 0
        matchedStrokeIndices = []
        attemptCount = 0
        consecutiveMisses = 0
        isComplete = false
    }

    func changeMode(_ newMode: PracticeMode) {
        mode = newMode
        reset()
    }
}
