import SwiftUI

struct iPadPracticeView: View {
    @StateObject private var practiceState: PracticeState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: PracticeHistoryStore
    @State private var canvasView: DrawingCanvasView?
    @State private var referenceView: KanjiReferenceView?
    @State private var feedbackView: FeedbackOverlayView?
    @State private var showCompletionCheck = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let onComplete: ((Int) -> Void)?

    init(
        kanjiData: KanjiData,
        mode: PracticeMode = .trace,
        context: RunContext = RunContext(),
        onComplete: ((Int) -> Void)? = nil
    ) {
        _practiceState = StateObject(wrappedValue: PracticeState(kanjiData: kanjiData, mode: mode, context: context))
        self.onComplete = onComplete
    }

    var body: some View {
        HStack(spacing: 0) {
            if settings.handedness == .left {
                canvasArea
                Divider()
                infoPanel
                    .frame(width: 280)
                    .padding()
            } else {
                infoPanel
                    .frame(width: 280)
                    .padding()
                Divider()
                canvasArea
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("Back")
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    let newScale = settings.practiceCanvasScale - AppSettings.canvasScaleStep
                    settings.practiceCanvasScale = max(AppSettings.canvasScaleRange.lowerBound, newScale)
                } label: {
                    Image(systemName: "minus")
                }
                .accessibilityLabel("Smaller canvas")
                .disabled(settings.practiceCanvasScale <= AppSettings.canvasScaleRange.lowerBound)

                Button {
                    let newScale = settings.practiceCanvasScale + AppSettings.canvasScaleStep
                    settings.practiceCanvasScale = min(AppSettings.canvasScaleRange.upperBound, newScale)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Larger canvas")
                .disabled(settings.practiceCanvasScale >= AppSettings.canvasScaleRange.upperBound)
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
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                practiceState.noteSceneLeftActive()
            }
        }
        .onAppear {
            practiceState.validationConfig = settings.validationConfig
            practiceState.cueOrder = settings.recallCueOrder
            practiceState.onRunCompleted = { record in
                history.add(record)
                onComplete?(record.misses)
            }
            practiceState.noteCueShown()
        }
    }

    // MARK: - Left Panel

    private var infoPanel: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(String(practiceState.kanjiData.character))
                .font(.system(size: 80))
                .accessibilityIdentifier("answerGlyph")

            readingsBlock

            strokeProgressDots

            VStack(spacing: 8) {
                PracticeModePicker(practiceState: practiceState)
                Text(practiceState.mode.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            controls

            Spacer()
        }
    }

    private var readingsBlock: some View {
        let kanji = practiceState.kanjiData
        return VStack(spacing: 4) {
            RecallCueText(
                cue: RecallCue(kanji: kanji, order: settings.recallCueOrder),
                alignment: .center,
                primaryFont: .body,
                secondaryFont: .subheadline
            )
            .multilineTextAlignment(.center)
            ReadingSpeakerButton(text: SpokenReading.text(for: kanji)) {
                practiceState.noteCueAudioPlayed()
            }
        }
    }

    private var strokeProgressDots: some View {
        StrokeProgressDots(practiceState: practiceState, palette: settings.colorPalette)
    }

    private var controls: some View {
        HStack(spacing: 32) {
            Button {
                handleUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }
            .disabled(practiceState.matchedStrokeIndices.isEmpty)
            .accessibilityLabel("Undo stroke")

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
    }

    // MARK: - Right Panel

    private var canvasArea: some View {
        GeometryReader { geo in
            let maxDim = min(geo.size.width, geo.size.height)
            let canvasSize = maxDim * settings.practiceCanvasScale

            canvasPanel
                .frame(width: canvasSize, height: canvasSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
    }

    private var canvasPanel: some View {
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
            hidesReference: false,
            notice: practiceState.lastRejection?.notice,
            startMarker: practiceState.startMarker,
            captureContext: StrokeCaptureContext(
                codePoint: practiceState.kanjiData.codePoint,
                mode: practiceState.mode.rawValue
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
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
