import UIKit

/// Shared practice-session flow used by both PracticeView (iPhone) and
/// iPadPracticeView, which previously duplicated it verbatim.
extension PracticeState {

    /// Validates a completed stroke and drives the accept/reject feedback.
    /// Returns true when this stroke completed the kanji.
    func handleCompletedStroke(
        points: [CGPoint],
        canvas: DrawingCanvasView,
        reference: KanjiReferenceView?,
        feedback: FeedbackOverlayView?
    ) -> Bool {
        guard !isComplete else { return false }

        beginDrawing()
        beginValidation()

        let result = StrokeValidator.identifyStroke(
            userPoints: points,
            referenceStrokes: kanjiData.strokes,
            unmatchedIndices: unmatchedIndices,
            canvasSize: canvas.bounds.size,
            expectedStrokeIndex: currentStrokeIndex,
            config: validationConfig
        )

        processValidationResult(result)

        switch phase {
        case .strokeAccepted(let strokeIndex):
            feedback?.showAccepted(points: points)
            reference?.markStrokeAccepted(at: strokeIndex)
            if let reference {
                applyGhostVisibility(to: reference)
            }
            acknowledgeResult()
            return isComplete

        case .strokeRejected:
            feedback?.showRejected(points: points)
            canvas.removeLastStroke()

            if shouldShowAutoHint {
                reference?.highlightStroke(at: currentStrokeIndex, alpha: 0.6)
                reference?.animateStrokeDrawing(at: currentStrokeIndex)
            }

            acknowledgeResult()
            return false

        default:
            return false
        }
    }

    /// Applies the mode-dependent visibility of every reference ghost stroke.
    func applyGhostVisibility(to reference: KanjiReferenceView) {
        for i in 0..<totalStrokes {
            if matchedStrokeIndices.contains(i) {
                reference.markStrokeAccepted(at: i)
                continue
            }

            switch mode {
            case .trace:
                if i == currentStrokeIndex {
                    reference.setStrokeVisibility(
                        .visible(alpha: mode.currentStrokeAlpha ?? 0.5), at: i
                    )
                } else {
                    reference.setStrokeVisibility(
                        .visible(alpha: mode.ghostStrokeAlpha ?? 0.3), at: i
                    )
                }

            case .strokeByStroke:
                if i == currentStrokeIndex {
                    reference.setStrokeVisibility(
                        .visible(alpha: mode.currentStrokeAlpha ?? 0.5), at: i
                    )
                    if mode.animateStrokeReveal {
                        reference.animateStrokeDrawing(at: i)
                    }
                } else {
                    reference.setStrokeVisibility(.hidden, at: i)
                }

            case .freeDraw:
                reference.setStrokeVisibility(.hidden, at: i)
            }
        }
    }
}
