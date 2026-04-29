import SwiftUI

struct iPadPracticeView: View {
    @StateObject private var practiceState: PracticeState
    @EnvironmentObject private var settings: AppSettings
    @State private var canvasView: DrawingCanvasView?
    @State private var referenceView: KanjiReferenceView?
    @State private var feedbackView: FeedbackOverlayView?
    @State private var showCompletionCheck = false
    @Environment(\.dismiss) private var dismiss

    let onComplete: ((Int) -> Void)?

    init(kanjiData: KanjiData, mode: PracticeMode = .trace, onComplete: ((Int) -> Void)? = nil) {
        _practiceState = StateObject(wrappedValue: PracticeState(kanjiData: kanjiData, mode: mode))
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
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    let newScale = settings.practiceCanvasScale - AppSettings.canvasScaleStep
                    settings.practiceCanvasScale = max(AppSettings.canvasScaleRange.lowerBound, newScale)
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(settings.practiceCanvasScale <= AppSettings.canvasScaleRange.lowerBound)

                Button {
                    let newScale = settings.practiceCanvasScale + AppSettings.canvasScaleStep
                    settings.practiceCanvasScale = min(AppSettings.canvasScaleRange.upperBound, newScale)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(settings.practiceCanvasScale >= AppSettings.canvasScaleRange.upperBound)
            }
        }
        .onChange(of: practiceState.mode) { _ in
            canvasView?.clearAll()
            feedbackView?.clearAll()
            applyGhostVisibility()
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

    // MARK: - Left Panel

    private var infoPanel: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(String(practiceState.kanjiData.character))
                .font(.system(size: 80))

            readingsBlock

            strokeProgressDots

            modePicker

            controls

            Spacer()
        }
    }

    private var readingsBlock: some View {
        VStack(spacing: 4) {
            if let on = practiceState.kanjiData.onYomi, !on.isEmpty {
                Text(on.joined(separator: "、 "))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if let kun = practiceState.kanjiData.kunYomi, !kun.isEmpty {
                Text(kun.joined(separator: "、 "))
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            if let meanings = practiceState.kanjiData.meanings, !meanings.isEmpty {
                Text(meanings.prefix(3).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
    }

    private var strokeProgressDots: some View {
        let total = practiceState.totalStrokes
        let dotSize: CGFloat = total <= 12 ? 10 : (total <= 20 ? 8 : 6)

        return HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
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

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { practiceState.mode },
            set: { practiceState.changeMode($0) }
        )) {
            ForEach(PracticeMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
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
}
