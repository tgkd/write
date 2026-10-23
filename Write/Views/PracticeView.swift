import SwiftUI

struct PracticeView: View {
    @StateObject private var practiceState: PracticeState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: PracticeHistoryStore
    @State private var canvasView: DrawingCanvasView?
    @State private var referenceView: KanjiReferenceView?
    @State private var feedbackView: FeedbackOverlayView?
    @State private var showCompletionCheck = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let onComplete: ((PracticeRecord) -> Void)?
    let showToolbar: Bool

    init(
        kanjiData: KanjiData,
        mode: PracticeMode = .trace,
        isRecall: Bool = false,
        showToolbar: Bool = true,
        context: RunContext = RunContext(),
        onComplete: ((PracticeRecord) -> Void)? = nil
    ) {
        _practiceState = StateObject(
            wrappedValue: PracticeState(kanjiData: kanjiData, mode: mode, isRecall: isRecall, context: context)
        )
        self.showToolbar = showToolbar
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 8) {
            kanjiHeader

            Spacer(minLength: 0)

            strokeProgressDots
                .padding(.horizontal)

            canvasArea
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)

            controls
                .padding(.bottom, 48)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showToolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
        .onChange(of: practiceState.mode) { _ in
            canvasView?.clearAll()
            feedbackView?.clearAll()
            showCompletionCheck = false
            applyGhostVisibility()
        }
        .onChange(of: settings.gradingStrictness) { _ in
            practiceState.validationConfig = settings.validationConfig
        }
        .onChange(of: settings.maskPathWidth) { _ in
            referenceView?.updateAppearance(
                lineWidth: settings.maskPathWidth,
                colorProvider: settings.colorPalette.strokeOrderColor
            )
            applyGhostVisibility()
        }
        .onChange(of: settings.colorPalette) { _ in
            referenceView?.updateAppearance(
                lineWidth: settings.maskPathWidth,
                colorProvider: settings.colorPalette.strokeOrderColor
            )
            feedbackView?.acceptedColor = settings.colorPalette.acceptedColor
            feedbackView?.rejectedColor = settings.colorPalette.rejectedColor
            applyGhostVisibility()
        }
        .onChange(of: practiceState.hint) { _ in
            applyGhostVisibility()
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                practiceState.noteSceneLeftActive()
            }
        }
        .onAppear {
            practiceState.validationConfig = settings.validationConfig
            practiceState.onRunCompleted = { record in
                history.add(record)
                onComplete?(record)
            }
            practiceState.noteCueShown()
        }
    }

    // MARK: - Subviews

    private var strokeProgressDots: some View {
        StrokeProgressDots(practiceState: practiceState, palette: settings.colorPalette)
    }

    private var kanjiHeader: some View {
        let kanji = practiceState.kanjiData
        return VStack(alignment: .leading, spacing: 2) {
            AnswerGlyph(
                kanji: kanji,
                isHidden: practiceState.hidesCharacter,
                fontSize: 40
            )
            if let romaji = kanji.romaji {
                Text(romaji)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let on = kanji.onYomi, !on.isEmpty {
                Text(on.joined(separator: "、 "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let kun = kanji.kunYomi, !kun.isEmpty {
                Text(kun.joined(separator: "、 "))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            if let meanings = kanji.meanings, !meanings.isEmpty {
                Text(meanings.prefix(3).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private var canvasArea: some View {
        PracticeCanvasArea(
            kanjiData: practiceState.kanjiData,
            lineWidth: settings.maskPathWidth,
            palette: settings.colorPalette,
            allowedTouchTypes: settings.allowedTouchTypes,
            pressureSensitivity: settings.pressureSensitivity,
            tiltSensitivity: settings.tiltSensitivity,
            smoothingStrength: settings.smoothingStrength,
            brushThickness: settings.brushThickness,
            showCompletionCheck: showCompletionCheck,
            hidesReference: practiceState.hidesGuide,
            notice: practiceState.lastRejection?.notice,
            startMarker: practiceState.startMarker,
            captureContext: StrokeCaptureContext(
                codePoint: practiceState.kanjiData.codePoint,
                mode: practiceState.isRecall ? PracticeRecord.recallMode : practiceState.mode.rawValue
            ),
            onStrokeBegan: { touchType in
                practiceState.noteStrokeBegan(touchType: touchType)
            },
            onStrokeCompleted: { points in
                handleStrokeCompleted(points: points)
            },
            onPencilDoubleTap: {
                handlePencilDoubleTap()
            },
            canvasView: $canvasView,
            referenceView: $referenceView,
            feedbackView: $feedbackView,
            onReferenceReady: {
                applyGhostVisibility()
                prewarmValidation()
            }
        )
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button {
                    handleUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3)
                }
                .disabled(practiceState.matchedStrokeIndices.isEmpty)
                .accessibilityLabel("Undo stroke")

                if practiceState.isRecall {
                    RecallHintButton(practiceState: practiceState)
                } else {
                    PracticeModePicker(practiceState: practiceState)
                }

                Button {
                    practiceState.reset()
                    canvasView?.clearAll()
                    feedbackView?.clearAll()
                    showCompletionCheck = false
                    applyGhostVisibility()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                }
                .accessibilityLabel("Start over")
            }

            Text(controlsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var controlsCaption: String {
        guard practiceState.isRecall else { return practiceState.mode.summary }
        switch practiceState.hint {
        case .unused: return String(localized: "Write it from memory.")
        case .character: return String(localized: "Character shown. Counts as a hint.")
        case .strokes: return String(localized: "Next stroke shown. Counts as a hint.")
        }
    }

    // MARK: - Logic

    private func handleStrokeCompleted(points: [CGPoint]) {
        guard let canvasView else { return }
        let completed = practiceState.handleCompletedStroke(
            points: points,
            canvas: canvasView,
            reference: referenceView,
            feedback: feedbackView
        )
        if completed {
            triggerCompletionFeedback()
        }
    }

    private func handlePencilDoubleTap() {
        handleUndo()
    }

    private func handleUndo() {
        guard practiceState.undoLastStroke() != nil else { return }
        canvasView?.removeLastStroke()
        showCompletionCheck = false
        applyGhostVisibility()
    }

    private func triggerCompletionFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showCompletionCheck = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showCompletionCheck = false
            }
        }
    }

    private func applyGhostVisibility() {
        guard let referenceView else { return }
        practiceState.applyGhostVisibility(to: referenceView)
    }

    private func prewarmValidation() {
        guard let size = canvasView?.bounds.size ?? referenceView?.bounds.size else { return }
        practiceState.prewarmReferenceSamples(canvasSize: size)
    }
}
