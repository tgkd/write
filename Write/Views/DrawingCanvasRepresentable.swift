import SwiftUI

/// UIViewRepresentable wrapper for DrawingCanvasView, exposing it to SwiftUI.
struct DrawingCanvasRepresentable: UIViewRepresentable {

    /// Called when a new point is added during drawing.
    var onPointAdded: ((CGPoint, Int) -> Void)?

    /// Called when a stroke is completed.
    var onStrokeCompleted: (([CGPoint], Int) -> Void)?

    /// A binding that provides external access to the underlying canvas view.
    @Binding var canvasView: DrawingCanvasView?

    func makeUIView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.onPointAdded = onPointAdded
        view.onStrokeCompleted = onStrokeCompleted
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            self.canvasView = view
        }
        return view
    }

    func updateUIView(_ uiView: DrawingCanvasView, context: Context) {
        uiView.onPointAdded = onPointAdded
        uiView.onStrokeCompleted = onStrokeCompleted
    }
}
