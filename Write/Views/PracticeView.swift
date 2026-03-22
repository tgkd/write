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
        HStack(spacing: 4) {
            ForEach(0..<practiceState.totalStrokes, id: \.self) { i in
                Circle()
                    .fill(dotFillColor(for: i))
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle()
                            .stroke(dotBorderColor(for: i), lineWidth: 1)
                    )
            }
        }
    }

    private var dotSize: CGFloat {
        let total = practiceState.totalStrokes
        if total <= 12 { return 10 }
        if total <= 20 { return 8 }
        return 6
    }

    private func dotFillColor(for index: Int) -> Color {
        if practiceState.matchedStrokeIndices.contains(index) {
            return Color(uiColor: settings.colorPalette.strokeOrderColor(
                index: index, total: practiceState.totalStrokes
            ))
        }
        if index == practiceState.currentStrokeIndex && !practiceState.isComplete {
            return Color(.systemGray4)
        }
        return Color(.systemGray6)
    }

    private func dotBorderColor(for index: Int) -> Color {
        if practiceState.matchedStrokeIndices.contains(index) {
            return .clear
        }
        if index == practiceState.currentStrokeIndex && !practiceState.isComplete {
            return Color(.systemGray3)
        }
        return Color(.systemGray5)
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
            onReferenceReady: { applyGhostVisibility() }
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
        guard !practiceState.isComplete else { return }
        guard let canvasView else { return }

        practiceState.beginDrawing()
        practiceState.beginValidation()

        let result = StrokeValidator.identifyStroke(
            userPoints: points,
            referenceStrokes: practiceState.kanjiData.strokes,
            unmatchedIndices: practiceState.unmatchedIndices,
            canvasSize: canvasView.bounds.size,
            expectedStrokeIndex: practiceState.currentStrokeIndex,
            config: practiceState.validationConfig
        )

        practiceState.processValidationResult(result)

        switch practiceState.phase {
        case .strokeAccepted(let strokeIndex):
            feedbackView?.showAccepted(points: points)
            referenceView?.markStrokeAccepted(at: strokeIndex)
            applyGhostVisibility()
            practiceState.acknowledgeResult()

            if practiceState.isComplete {
                triggerCompletionFeedback()
            }

        case .strokeRejected:
            feedbackView?.showRejected(points: points)
            canvasView.removeLastStroke()

            if practiceState.shouldShowAutoHint {
                let idx = practiceState.currentStrokeIndex
                referenceView?.highlightStroke(at: idx, alpha: 0.6)
                referenceView?.animateStrokeDrawing(at: idx)
            }

            practiceState.acknowledgeResult()

        default:
            break
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
        let mode = practiceState.mode
        let currentIndex = practiceState.currentStrokeIndex

        for i in 0..<practiceState.totalStrokes {
            if practiceState.matchedStrokeIndices.contains(i) {
                referenceView.markStrokeAccepted(at: i)
                continue
            }

            switch mode {
            case .trace:
                if i == currentIndex {
                    referenceView.setStrokeVisibility(
                        .visible(alpha: mode.currentStrokeAlpha ?? 0.5), at: i
                    )
                } else {
                    referenceView.setStrokeVisibility(
                        .visible(alpha: mode.ghostStrokeAlpha ?? 0.3), at: i
                    )
                }

            case .strokeByStroke:
                if i == currentIndex {
                    referenceView.setStrokeVisibility(
                        .visible(alpha: mode.currentStrokeAlpha ?? 0.5), at: i
                    )
                    if mode.animateStrokeReveal {
                        referenceView.animateStrokeDrawing(at: i)
                    }
                } else {
                    referenceView.setStrokeVisibility(.hidden, at: i)
                }

            case .freeDraw:
                referenceView.setStrokeVisibility(.hidden, at: i)
            }
        }
    }
}
