import SwiftUI

struct WritingPencilInteraction: UIViewRepresentable {
    let onDoubleTap: () -> Void

    func makeCoordinator() -> PencilActionResponder {
        PencilActionResponder(action: onDoubleTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let interaction = UIPencilInteraction()
        interaction.delegate = context.coordinator
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = onDoubleTap
    }
}
