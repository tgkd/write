import Combine
import CoreGraphics
import Foundation
import UIKit

@MainActor
final class PracticeState: ObservableObject {

    enum Phase: Equatable {
        case waitingForInput
        case userDrawing
        case validating
        case strokeAccepted(strokeIndex: Int)
        case strokeRejected
    }

    private struct RunDetails {
        var shownAt: Date?
        var firstTouchAt: Date?
        var pendingTouch: (input: InputKind, at: Date)?
        var inputs: Set<InputKind> = []
        var undos = 0
        var gradedSetup: (config: ValidationConfig, canvasSize: CGSize?)?
        var configChanged = false
        var interrupted = false
        var rejectedStroke: Int?
        var cueAudioPlays = 0
        var strokes: [StrokeStat]

        init(strokeCount: Int, shownAt: Date? = nil) {
            self.shownAt = shownAt
            strokes = Array(repeating: StrokeStat(), count: strokeCount)
        }

        var input: InputKind? {
            guard let only = inputs.first else {
                return nil
            }
            return inputs.count == 1 ? only : .mixed
        }
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
    let context: RunContext
    var validationConfig: ValidationConfig
    var now: () -> Date = Date.init
    var idiom: String
    var appVersion: String?
    var onRunCompleted: ((PracticeRecord) -> Void)?
    var cueOrder: RecallCueOrder = .meaningsFirst

    private var runStartedAt: Date?
    private var runRecorded = false
    private var details: RunDetails

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

    var isGuideless: Bool {
        isRecall || mode == .copy
    }

    var startMarker: CGPoint? {
        guard isGuideless, mode == .copy || hidesGuide, matchedStrokeIndices.isEmpty else {
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

    init(
        kanjiData: KanjiData,
        mode: PracticeMode = .trace,
        isRecall: Bool = false,
        config: ValidationConfig = .standard,
        context: RunContext = RunContext()
    ) {
        self.kanjiData = kanjiData
        self.isRecall = isRecall
        self.mode = isRecall ? .strokeByStroke : mode
        self.validationConfig = config
        self.context = context
        self.idiom = Self.deviceIdiom()
        self.appVersion = Self.bundleVersion()
        self.details = RunDetails(strokeCount: kanjiData.strokes.count)
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

    func noteCueShown() {
        guard details.shownAt == nil else {
            return
        }
        details.shownAt = now()
    }

    func noteStrokeBegan(_ input: InputKind) {
        details.pendingTouch = (input, now())
    }

    func noteCueAudioPlayed() {
        guard !runRecorded else {
            return
        }
        details.cueAudioPlays += 1
    }

    func noteSceneLeftActive() {
        guard details.shownAt != nil, !runRecorded else {
            return
        }
        details.interrupted = true
    }

    func processValidationResult(_ result: StrokeValidationResult, canvasSize: CGSize? = nil) {
        guard phase == .validating else { return }

        if runStartedAt == nil {
            runStartedAt = now()
        }
        noteGradedAttempt(canvasSize: canvasSize)

        let expected = currentStrokeIndex
        let hintName = isRecall ? hint.recordName : nil
        updateStroke(expected) { $0.recordAttempt(hint: hintName) }

        if result.accepted, let matchedIndex = result.matchedStrokeIndex, result.correctOrder {
            updateStroke(expected) { $0.acceptedHint = hintName }
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
            updateStroke(expected) { $0.recordRejection(result) }
            details.rejectedStroke = expected
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
        details.undos += 1
        updateStroke(lastDrawn) { $0.undone += 1 }
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
        details = RunDetails(strokeCount: totalStrokes, shownAt: now())
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
        if let stroke = details.rejectedStroke {
            updateStroke(stroke) { $0.evidence.disputed += 1 }
        }
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
        let canvasSize = details.gradedSetup?.canvasSize
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
            evidence: missEvidence,
            sessionID: context.sessionID,
            slot: context.slot,
            origin: context.origin?.rawValue,
            hint: hint.recordName,
            undos: details.undos,
            input: details.input?.rawValue,
            canvasWidth: canvasSize.map { Double($0.width) },
            canvasHeight: canvasSize.map { Double($0.height) },
            idiom: idiom,
            appVersion: appVersion,
            shownAt: details.shownAt,
            firstTouchAt: details.firstTouchAt,
            firstTouchDelayMs: Self.milliseconds(from: details.shownAt, to: details.firstTouchAt),
            interrupted: details.interrupted,
            configChanged: details.configChanged,
            strokes: details.strokes,
            cueOrder: isRecall ? cueOrder.rawValue : nil,
            cueAudioPlays: details.cueAudioPlays > 0 ? details.cueAudioPlays : nil
        )
        onRunCompleted?(record)
    }

    private func noteGradedAttempt(canvasSize: CGSize?) {
        if let touch = details.pendingTouch {
            details.inputs.insert(touch.input)
            if details.firstTouchAt == nil {
                details.firstTouchAt = touch.at
            }
            details.pendingTouch = nil
        }
        let size = canvasSize.flatMap(Self.recordableSize)
        guard let setup = details.gradedSetup else {
            details.gradedSetup = (validationConfig, size)
            return
        }
        if setup.config != validationConfig {
            details.configChanged = true
        }
        if let first = setup.canvasSize, let size, first != size {
            details.configChanged = true
        }
    }

    private func updateStroke(_ index: Int, _ update: (inout StrokeStat) -> Void) {
        guard details.strokes.indices.contains(index) else {
            return
        }
        update(&details.strokes[index])
    }

    private static func milliseconds(from start: Date?, to end: Date?) -> Int? {
        guard let start, let end else {
            return nil
        }
        let interval = end.timeIntervalSince(start)
        guard interval.isFinite, interval >= 0 else {
            return nil
        }
        return Int((interval * 1000).rounded())
    }

    private static func recordableSize(_ size: CGSize) -> CGSize? {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            return nil
        }
        return size
    }

    private static func deviceIdiom() -> String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return "phone"
        case .pad:
            return "pad"
        default:
            return "other"
        }
    }

    private static func bundleVersion() -> String? {
        let info = Bundle.main.infoDictionary
        guard let version = info?["CFBundleShortVersionString"] as? String,
              let build = info?["CFBundleVersion"] as? String else {
            return nil
        }
        return "\(version) (\(build))"
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
