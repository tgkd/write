import SwiftUI

struct WritingPencilInteraction: UIViewRepresentable {
    let onDoubleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDoubleTap: onDoubleTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let interaction = UIPencilInteraction()
        interaction.delegate = context.coordinator
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDoubleTap = onDoubleTap
    }

    final class Coordinator: NSObject, UIPencilInteractionDelegate {
        var onDoubleTap: () -> Void

        init(onDoubleTap: @escaping () -> Void) {
            self.onDoubleTap = onDoubleTap
        }

        nonisolated func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            MainActor.assumeIsolated {
                if UIPencilInteraction.preferredTapAction != .ignore {
                    onDoubleTap()
                }
            }
        }
    }
}
