import SwiftUI

struct PracticeView: View {
    @StateObject private var practiceState: PracticeState
    @EnvironmentObject private var settings: AppSettings
    @State private var canvasView: DrawingCanvasView?
    @State private var referenceView: KanjiReferenceView?
    @State private var feedbackView: FeedbackOverlayView?
    @Environment(\.dismiss) private var dismiss

    init(kanjiData: KanjiData) {
        _practiceState = StateObject(wrappedValue: PracticeState(kanjiData: kanjiData))
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.backward")
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
        ZStack {
            KanjiReferenceRepresentable(
                kanjiData: practiceState.kanjiData,
                lineWidth: settings.maskPathWidth,
                palette: settings.colorPalette,
                referenceView: $referenceView,
                onReady: { applyGhostVisibility() }
            )

            DrawingCanvasRepresentable(
                onStrokeCompleted: { points, _ in
                    handleStrokeCompleted(points: points)
                },
                canvasView: $canvasView
            )

            FeedbackOverlayRepresentable(
                palette: settings.colorPalette,
                feedbackView: $feedbackView
            )
        }
    }

    private var controls: some View {
        HStack(spacing: 32) {
            Button {
                canvasView?.clearAll()
                feedbackView?.clearAll()
            } label: {
                Image(systemName: "eraser")
                    .font(.title3)
            }

            Button {
                practiceState.reset()
                canvasView?.clearAll()
                feedbackView?.clearAll()
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
            canvasView.removeLastStroke()
            applyGhostVisibility()
            practiceState.acknowledgeResult()

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

// MARK: - UIViewRepresentable wrappers

private struct KanjiReferenceRepresentable: UIViewRepresentable {
    let kanjiData: KanjiData
    let lineWidth: CGFloat
    let palette: ColorPalette
    @Binding var referenceView: KanjiReferenceView?
    var onReady: (() -> Void)?

    func makeUIView(context: Context) -> KanjiReferenceView {
        let view = KanjiReferenceView()
        view.backgroundColor = .clear
        view.strokeLineWidth = lineWidth
        view.colorProvider = palette.strokeOrderColor
        view.onLayersRebuilt = { [weak view] in
            guard let view else { return }
            DispatchQueue.main.async {
                self.referenceView = view
                self.onReady?()
            }
        }
        view.configure(with: kanjiData)
        return view
    }

    func updateUIView(_ uiView: KanjiReferenceView, context: Context) {
        uiView.updateAppearance(lineWidth: lineWidth, colorProvider: palette.strokeOrderColor)
    }
}

private struct FeedbackOverlayRepresentable: UIViewRepresentable {
    let palette: ColorPalette
    @Binding var feedbackView: FeedbackOverlayView?

    func makeUIView(context: Context) -> FeedbackOverlayView {
        let view = FeedbackOverlayView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.acceptedColor = palette.acceptedColor
        view.rejectedColor = palette.rejectedColor
        DispatchQueue.main.async {
            self.feedbackView = view
        }
        return view
    }

    func updateUIView(_ uiView: FeedbackOverlayView, context: Context) {
        uiView.acceptedColor = palette.acceptedColor
        uiView.rejectedColor = palette.rejectedColor
    }
}
