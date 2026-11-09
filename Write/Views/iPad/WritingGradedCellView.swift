import SwiftUI

struct WritingGradedCellView: View {
    let cell: WritingSession.Cell
    @ObservedObject var slotState: PracticeState
    @ObservedObject var ink: WritingInkStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var references: References

    init(cell: WritingSession.Cell, slotState: PracticeState, ink: WritingInkStore) {
        self.cell = cell
        self.slotState = slotState
        self.ink = ink
        _references = StateObject(wrappedValue: References(canvas: ink.canvas(for: cell.id)))
    }

    var body: some View {
        PracticeCanvasArea(
            kanjiData: slotState.kanjiData, lineWidth: settings.maskPathWidth, palette: settings.colorPalette,
            allowedTouchTypes: settings.allowedTouchTypes,
            pressureSensitivity: settings.pressureSensitivity, tiltSensitivity: settings.tiltSensitivity,
            smoothingStrength: settings.smoothingStrength, brushThickness: settings.brushThickness,
            showCompletionCheck: false, hidesReference: slotState.hidesGuide, showsGrid: settings.showPracticeGrid,
            notice: settings.rejectionNotice(for: slotState.lastRejection), startMarker: slotState.startMarker,
            captureContext: StrokeCaptureContext(codePoint: slotState.kanjiData.codePoint, mode: slotState.isRecall ? "writing-empty" : "writing-trace"),
            retainedCanvasView: ink.canvas(for: cell.id), canvasIdentifier: "writing.canvas.\(cell.id)", installsPencilInteraction: false,
            onStrokeBegan: { [weak slotState] type in slotState?.noteStrokeBegan(touchType: type) },
            onStrokeCompleted: { [weak slotState, weak references, weak ink, id = cell.id] points in
                guard let slotState, let canvas = references?.canvas else {
                    return
                }
                _ = slotState.handleCompletedStroke(points: points, canvas: canvas, reference: references?.reference, feedback: references?.feedback)
                ink?.noteStroke(in: id)
                if slotState.isComplete {
                    ink?.snapshot(id)
                }
            },
            canvasView: $references.canvas, referenceView: $references.reference, feedbackView: $references.feedback,
            onReferenceReady: { [weak slotState, weak references] in
                guard let slotState, let reference = references?.reference else {
                    return
                }
                slotState.applyGhostVisibility(to: reference)
                slotState.prewarmReferenceSamples(canvasSize: reference.bounds.size)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 3))
        .onAppear { slotState.noteCueShown() }
        .onChange(of: slotState.hint) { _ in applyGuide() }
        .onChange(of: slotState.matchedStrokeIndices) { _ in applyGuide() }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                slotState.noteSceneLeftActive()
            }
        }
    }

    private func applyGuide() {
        if let reference = references.reference {
            slotState.applyGhostVisibility(to: reference)
        }
    }

    final class References: ObservableObject {
        @Published var canvas: DrawingCanvasView?
        @Published var reference: KanjiReferenceView?
        @Published var feedback: FeedbackOverlayView?

        init(canvas: DrawingCanvasView) {
            self.canvas = canvas
        }
    }
}
