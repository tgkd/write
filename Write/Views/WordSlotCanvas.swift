import SwiftUI

struct WordSlotCanvas: View {
    @ObservedObject var slotState: PracticeState
    let showCompletionCheck: Bool
    let isLocked: Bool
    let onSlotCompleted: () -> Void
    let onResetWord: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @State private var canvasView: DrawingCanvasView?
    @State private var referenceView: KanjiReferenceView?
    @State private var feedbackView: FeedbackOverlayView?

    var body: some View {
        VStack(spacing: 8) {
            StrokeProgressDots(practiceState: slotState, palette: settings.colorPalette)
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
        }
        .onChange(of: slotState.hint) { _ in
            applyGhostVisibility()
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
    }

    private var canvasArea: some View {
        PracticeCanvasArea(
            kanjiData: slotState.kanjiData,
            lineWidth: settings.maskPathWidth,
            palette: settings.colorPalette,
            allowedTouchTypes: settings.allowedTouchTypes,
            pressureSensitivity: settings.pressureSensitivity,
            tiltSensitivity: settings.tiltSensitivity,
            smoothingStrength: settings.smoothingStrength,
            brushThickness: settings.brushThickness,
            showCompletionCheck: showCompletionCheck,
            hidesReference: slotState.hidesGuide,
            notice: slotState.lastRejection?.notice,
            startMarker: slotState.startMarker,
            canDispute: slotState.canDisputeLastRejection,
            onDispute: { slotState.disputeLastRejection() },
            captureContext: StrokeCaptureContext(
                codePoint: slotState.kanjiData.codePoint,
                mode: "word"
            ),
            onStrokeCompleted: { points in
                handleStrokeCompleted(points: points)
            },
            onPencilDoubleTap: {
                handleUndo()
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
                .disabled(isLocked || slotState.matchedStrokeIndices.isEmpty)
                .accessibilityLabel("Undo stroke")
                .accessibilityIdentifier("word.undo")

                RecallHintButton(practiceState: slotState)
                    .disabled(isLocked)

                Button {
                    onResetWord()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                }
                .disabled(isLocked)
                .accessibilityLabel("Restart word")
                .accessibilityIdentifier("word.reset")
            }

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var caption: String {
        switch slotState.hint {
        case .unused:
            return String(localized: "Write the kanji for the highlighted box.")
        case .character:
            return String(localized: "Character shown. Counts as a hint.")
        case .strokes:
            return String(localized: "Next stroke shown. Counts as a hint.")
        }
    }

    private func handleStrokeCompleted(points: [CGPoint]) {
        guard !isLocked, let canvasView else {
            return
        }
        let completed = slotState.handleCompletedStroke(
            points: points,
            canvas: canvasView,
            reference: referenceView,
            feedback: feedbackView
        )
        if completed {
            onSlotCompleted()
        }
    }

    private func handleUndo() {
        guard !isLocked, slotState.undoLastStroke() != nil else {
            return
        }
        canvasView?.removeLastStroke()
        applyGhostVisibility()
    }

    private func applyGhostVisibility() {
        guard let referenceView else {
            return
        }
        slotState.applyGhostVisibility(to: referenceView)
    }

    private func prewarmValidation() {
        guard let size = canvasView?.bounds.size ?? referenceView?.bounds.size else {
            return
        }
        slotState.prewarmReferenceSamples(canvasSize: size)
    }
}
