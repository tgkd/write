import SwiftUI

/// UIViewRepresentable wrapper for DrawingCanvasView, exposing it to SwiftUI.
/// Owns the screen's single UIPencilInteraction and routes its double-tap.
struct DrawingCanvasRepresentable: UIViewRepresentable {

    var onPointAdded: ((CGPoint, Int) -> Void)?
    var onStrokeCompleted: (([CGPoint], Int) -> Void)?
    var onPencilDoubleTap: (() -> Void)?

    var allowedTouchTypes: Set<UITouch.TouchType> = [.direct, .pencil]
    var pressureSensitivity: PressureSensitivity = .off
    var tiltSensitivity: TiltSensitivity = .off
    var smoothingStrength: SmoothingStrength = .medium
    var brushThickness: BrushThickness = .medium
    var captureContext: StrokeCaptureContext?

    @Binding var canvasView: DrawingCanvasView?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.onPointAdded = onPointAdded
        view.onStrokeCompleted = onStrokeCompleted
        view.onStrokeCaptured = strokeCaptureHandler()
        view.allowedTouchTypes = allowedTouchTypes
        applyBrushSettings(to: view)
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "drawingCanvas"
        view.accessibilityLabel = String(localized: "Drawing canvas")
        view.accessibilityTraits = .allowsDirectInteraction

        let interaction = UIPencilInteraction()
        interaction.delegate = context.coordinator
        view.addInteraction(interaction)
        context.coordinator.onPencilDoubleTap = onPencilDoubleTap

        DispatchQueue.main.async {
            self.canvasView = view
        }
        return view
    }

    func updateUIView(_ uiView: DrawingCanvasView, context: Context) {
        uiView.onPointAdded = onPointAdded
        uiView.onStrokeCompleted = onStrokeCompleted
        uiView.onStrokeCaptured = strokeCaptureHandler()
        uiView.allowedTouchTypes = allowedTouchTypes
        context.coordinator.onPencilDoubleTap = onPencilDoubleTap
        applyBrushSettings(to: uiView)
    }

    private func strokeCaptureHandler() -> ((CanvasStrokeCapture) -> Void)? {
        guard let captureContext, StrokeCaptureRecorder.shared.isEnabled else {
            return nil
        }
        return { capture in
            StrokeCaptureRecorder.shared.record(CapturedStroke(capture: capture, context: captureContext))
        }
    }

    private func applyBrushSettings(to view: DrawingCanvasView) {
        view.brushConfig = BrushStroke.Config(
            pressure: pressureSensitivity,
            tilt: tiltSensitivity,
            smoothing: smoothingStrength,
            thickness: brushThickness
        )
    }

    @MainActor
    final class Coordinator: NSObject, UIPencilInteractionDelegate {
        var onPencilDoubleTap: (() -> Void)?

        nonisolated func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            MainActor.assumeIsolated {
                guard UIPencilInteraction.preferredTapAction != .ignore else { return }
                onPencilDoubleTap?()
            }
        }
    }
}
