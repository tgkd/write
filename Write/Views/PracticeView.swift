import SwiftUI

struct PracticeView: View {
    @StateObject private var practiceState: PracticeState
    @State private var canvasView: DrawingCanvasView?
    @State private var referenceView: KanjiReferenceView?
    @State private var feedbackView: FeedbackOverlayView?

    init(kanjiData: KanjiData) {
        _practiceState = StateObject(wrappedValue: PracticeState(kanjiData: kanjiData))
    }

    var body: some View {
        VStack(spacing: 16) {
            modePicker
            statusBar

            canvasArea
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal)

            controls
        }
        .navigationTitle(String(practiceState.kanjiData.character))
        .onChange(of: practiceState.mode) { _ in
            canvasView?.clearAll()
            feedbackView?.clearAll()
            applyGhostVisibility()
        }
    }

    // MARK: - Subviews

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
        .padding(.horizontal)
    }

    private var statusBar: some View {
        HStack {
            Text("\(practiceState.matchedStrokeIndices.count)/\(practiceState.totalStrokes)")
                .monospacedDigit()
            Spacer()
            if practiceState.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }

    private var canvasArea: some View {
        ZStack {
            KanjiReferenceRepresentable(
                kanjiData: practiceState.kanjiData,
                referenceView: $referenceView,
                onReady: { applyGhostVisibility() }
            )

            DrawingCanvasRepresentable(
                onStrokeCompleted: { points, _ in
                    handleStrokeCompleted(points: points)
                },
                canvasView: $canvasView
            )

            FeedbackOverlayRepresentable(feedbackView: $feedbackView)
        }
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Button("Clear") {
                canvasView?.clearAll()
                feedbackView?.clearAll()
            }
            Button("Reset") {
                practiceState.reset()
                canvasView?.clearAll()
                feedbackView?.clearAll()
                applyGhostVisibility()
            }
        }
        .padding(.horizontal)
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
    @Binding var referenceView: KanjiReferenceView?
    var onReady: (() -> Void)?

    func makeUIView(context: Context) -> KanjiReferenceView {
        let view = KanjiReferenceView()
        view.backgroundColor = .clear
        view.configure(with: kanjiData)
        DispatchQueue.main.async {
            self.referenceView = view
            self.onReady?()
        }
        return view
    }

    func updateUIView(_ uiView: KanjiReferenceView, context: Context) {}
}

private struct FeedbackOverlayRepresentable: UIViewRepresentable {
    @Binding var feedbackView: FeedbackOverlayView?

    func makeUIView(context: Context) -> FeedbackOverlayView {
        let view = FeedbackOverlayView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            self.feedbackView = view
        }
        return view
    }

    func updateUIView(_ uiView: FeedbackOverlayView, context: Context) {}
}
