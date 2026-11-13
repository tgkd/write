import SwiftUI

/// UIViewRepresentable wrapper for DrawingCanvasView, exposing it to SwiftUI.
/// Owns the screen's single UIPencilInteraction and routes its double-tap.
struct DrawingCanvasRepresentable: UIViewRepresentable {

    var onPointAdded: ((CGPoint, Int) -> Void)?
    var onStrokeBegan: ((UITouch.TouchType) -> Void)?
    var onStrokeCompleted: (([CGPoint], Int) -> Void)?
    var onPencilDoubleTap: (() -> Void)?

    var allowedTouchTypes: Set<UITouch.TouchType> = [.direct, .pencil]
    var pressureSensitivity: PressureSensitivity = .off
    var tiltSensitivity: TiltSensitivity = .off
    var smoothingStrength: SmoothingStrength = .medium
    var brushThickness: BrushThickness = .medium
    var captureContext: StrokeCaptureContext?
    var retainedCanvasView: DrawingCanvasView?
    var canvasIdentifier: String = "drawingCanvas"
    var canvasLabel: String?
    var installsPencilInteraction: Bool = true
    var accessibilityProgress: String?

    @Binding var canvasView: DrawingCanvasView?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> DrawingCanvasView {
        let view = retainedCanvasView ?? DrawingCanvasView()
        view.onPointAdded = onPointAdded
        view.onStrokeBegan = onStrokeBegan
        view.onStrokeCompleted = onStrokeCompleted
        view.onStrokeCaptured = strokeCaptureHandler()
        view.allowedTouchTypes = allowedTouchTypes
        applyBrushSettings(to: view)
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = canvasIdentifier
        view.accessibilityLabel = canvasLabel ?? String(localized: "Drawing canvas")
        view.accessibilityTraits = .allowsDirectInteraction
        view.accessibilityHint = String(localized: "Draw the strokes here.")
        applyAccessibilityProgress(to: view)
        if retainedCanvasView != nil {
            view.accessibilityValue = String(view.strokeCount)
            if view.gestureRecognizers?.contains(where: { $0 is WritingTouchRecognizer }) != true {
                let gesture = WritingTouchRecognizer()
                gesture.cancelsTouchesInView = false
                gesture.delaysTouchesBegan = false
                gesture.allowedTouchTypes = allowedTouchTypes.map { NSNumber(value: $0.rawValue) }
                view.addGestureRecognizer(gesture)
            }
        }

        if installsPencilInteraction {
            let interaction = view.interactions.compactMap { $0 as? UIPencilInteraction }.first ?? UIPencilInteraction()
            interaction.delegate = context.coordinator
            if interaction.view == nil {
                view.addInteraction(interaction)
            }
        }
        context.coordinator.onPencilDoubleTap = onPencilDoubleTap

        DispatchQueue.main.async {
            self.canvasView = view
        }
        return view
    }

    func updateUIView(_ uiView: DrawingCanvasView, context: Context) {
        uiView.onPointAdded = onPointAdded
        uiView.onStrokeBegan = onStrokeBegan
        uiView.onStrokeCompleted = onStrokeCompleted
        uiView.onStrokeCaptured = strokeCaptureHandler()
        uiView.allowedTouchTypes = allowedTouchTypes
        for gesture in uiView.gestureRecognizers ?? [] where gesture is WritingTouchRecognizer {
            gesture.allowedTouchTypes = allowedTouchTypes.map { NSNumber(value: $0.rawValue) }
        }
        context.coordinator.onPencilDoubleTap = onPencilDoubleTap
        applyBrushSettings(to: uiView)
        uiView.accessibilityLabel = canvasLabel ?? String(localized: "Drawing canvas")
        applyAccessibilityProgress(to: uiView)
    }

    private func applyAccessibilityProgress(to view: DrawingCanvasView) {
        guard let accessibilityProgress else {
            return
        }
        view.accessibilityValue = accessibilityProgress
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
