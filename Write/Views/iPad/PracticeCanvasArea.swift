import SwiftUI

struct PracticeCanvasArea: View {
    let kanjiData: KanjiData
    let lineWidth: CGFloat
    let palette: ColorPalette
    let allowedTouchTypes: Set<UITouch.TouchType>
    let pressureSensitivity: PressureSensitivity
    let showCompletionCheck: Bool

    var onStrokeCompleted: (([CGPoint]) -> Void)?
    var onPencilDoubleTap: (() -> Void)?

    @Binding var canvasView: DrawingCanvasView?
    @Binding var referenceView: KanjiReferenceView?
    @Binding var feedbackView: FeedbackOverlayView?

    var onReferenceReady: (() -> Void)?

    var body: some View {
        ZStack {
            KanjiReferenceRepresentable(
                kanjiData: kanjiData,
                lineWidth: lineWidth,
                palette: palette,
                referenceView: $referenceView,
                onReady: { onReferenceReady?() }
            )

            DrawingCanvasRepresentable(
                onStrokeCompleted: { points, _ in
                    onStrokeCompleted?(points)
                },
                onPencilDoubleTap: onPencilDoubleTap,
                allowedTouchTypes: allowedTouchTypes,
                pressureSensitivity: pressureSensitivity,
                canvasView: $canvasView
            )

            FeedbackOverlayRepresentable(
                palette: palette,
                feedbackView: $feedbackView
            )

            if showCompletionCheck {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
    }
}

// MARK: - UIViewRepresentable wrappers

struct KanjiReferenceRepresentable: UIViewRepresentable {
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

struct FeedbackOverlayRepresentable: UIViewRepresentable {
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
