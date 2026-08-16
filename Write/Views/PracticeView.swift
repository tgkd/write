import SwiftUI

struct PracticeView: View {
    @StateObject private var practiceState: PracticeState
    @EnvironmentObject private var settings: AppSettings
    @State private var canvasView: DrawingCanvasView?
    @State private var referenceView: KanjiReferenceView?
    @State private var feedbackView: FeedbackOverlayView?
    @State private var showCompletionCheck = false
    @Environment(\.dismiss) private var dismiss

    let onComplete: ((Int) -> Void)?
    let onModeChange: ((PracticeMode) -> Void)?
    let showToolbar: Bool

    init(kanjiData: KanjiData, mode: PracticeMode = .trace, showToolbar: Bool = true, onComplete: ((Int) -> Void)? = nil, onModeChange: ((PracticeMode) -> Void)? = nil) {
        _practiceState = StateObject(wrappedValue: PracticeState(kanjiData: kanjiData, mode: mode))
        self.showToolbar = showToolbar
        self.onComplete = onComplete
        self.onModeChange = onModeChange
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
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Mode", selection: Binding(
                        get: { practiceState.mode },
                        set: { practiceState.changeMode($0) }
                    )) {
                        ForEach(PracticeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                } label: {
                    Text(practiceState.mode.displayName)
                        .font(.subheadline)
                }
            }
        }
        .onChange(of: practiceState.mode) { _ in
            canvasView?.clearAll()
            feedbackView?.clearAll()
            applyGhostVisibility()
            onModeChange?(practiceState.mode)
        }
        .onChange(of: settings.maskPathWidth) { _ in
            practiceState.validationConfig = settings.validationConfig
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
        .onAppear {
            practiceState.validationConfig = settings.validationConfig
        }
    }

    // MARK: - Subviews

    private var strokeProgressDots: some View {
        StrokeProgressDots(practiceState: practiceState, palette: settings.colorPalette)
    }

    private var kanjiHeader: some View {
        let kanji = practiceState.kanjiData
        return VStack(alignment: .leading, spacing: 2) {
            Text(String(kanji.character))
                .font(.system(size: 40))
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
        HStack(spacing: 32) {
            Button {
                handleUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }
            .disabled(practiceState.matchedStrokeIndices.isEmpty)

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
        }
        .padding(.bottom, 4)
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

        onComplete?(practiceState.attemptCount)
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
