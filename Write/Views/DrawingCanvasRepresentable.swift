import SwiftUI

/// UIViewRepresentable wrapper for DrawingCanvasView, exposing it to SwiftUI.
struct DrawingCanvasRepresentable: UIViewRepresentable {

    var onPointAdded: ((CGPoint, Int) -> Void)?
    var onStrokeCompleted: (([CGPoint], Int) -> Void)?
    var onPencilDoubleTap: (() -> Void)?
    var onPencilSqueeze: (() -> Void)?

    var allowedTouchTypes: Set<UITouch.TouchType> = [.direct, .pencil]
    var pressureSensitivity: PressureSensitivity = .off

    @Binding var canvasView: DrawingCanvasView?

    func makeUIView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.onPointAdded = onPointAdded
        view.onStrokeCompleted = onStrokeCompleted
        view.onPencilDoubleTap = onPencilDoubleTap
        view.onPencilSqueeze = onPencilSqueeze
        view.allowedTouchTypes = allowedTouchTypes
        view.brushConfig.pressureSensitivity = pressureSensitivity
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            self.canvasView = view
        }
        return view
    }

    func updateUIView(_ uiView: DrawingCanvasView, context: Context) {
        uiView.onPointAdded = onPointAdded
        uiView.onStrokeCompleted = onStrokeCompleted
        uiView.onPencilDoubleTap = onPencilDoubleTap
        uiView.onPencilSqueeze = onPencilSqueeze
        uiView.allowedTouchTypes = allowedTouchTypes
        uiView.brushConfig.pressureSensitivity = pressureSensitivity
    }
}
