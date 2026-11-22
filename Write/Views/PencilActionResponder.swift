import UIKit

@MainActor
final class PencilActionResponder: NSObject, UIPencilInteractionDelegate {
    var action: (() -> Void)?

    init(action: (() -> Void)? = nil) {
        self.action = action
        super.init()
    }

    func handleTap(preference: UIPencilPreferredAction) {
        guard preference != .ignore else {
            return
        }
        action?()
    }

    @available(iOS 17.5, *)
    func handleSqueeze(phase: UIPencilInteraction.Phase, preference: UIPencilPreferredAction) {
        guard phase == .ended, preference != .ignore else {
            return
        }
        action?()
    }

    @available(iOS, deprecated: 17.5)
    nonisolated func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        MainActor.assumeIsolated {
            handleTap(preference: UIPencilInteraction.preferredTapAction)
        }
    }

    @available(iOS 17.5, *)
    nonisolated func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        MainActor.assumeIsolated {
            handleTap(preference: UIPencilInteraction.preferredTapAction)
        }
    }

    @available(iOS 17.5, *)
    nonisolated func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        MainActor.assumeIsolated {
            handleSqueeze(phase: squeeze.phase, preference: UIPencilInteraction.preferredSqueezeAction)
        }
    }
}
