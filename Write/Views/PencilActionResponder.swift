import UIKit

@MainActor
final class PencilActionResponder: NSObject, UIPencilInteractionDelegate {
    var action: (() -> Void)?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, action: (() -> Void)? = nil) {
        self.defaults = defaults
        self.action = action
        super.init()
    }

    func handleTap(preference: UIPencilPreferredAction, isEnabled: Bool = true) {
        guard isEnabled, preference != .ignore else {
            return
        }
        action?()
    }

    @available(iOS 17.5, *)
    func handleSqueeze(phase: UIPencilInteraction.Phase, preference: UIPencilPreferredAction, isEnabled: Bool = true) {
        guard isEnabled, phase == .ended, preference != .ignore else {
            return
        }
        action?()
    }

    @available(iOS, deprecated: 17.5)
    nonisolated func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        MainActor.assumeIsolated {
            handleTap(
                preference: UIPencilInteraction.preferredTapAction,
                isEnabled: AppSettings.isPencilDoubleTapEnabled(in: defaults)
            )
        }
    }

    @available(iOS 17.5, *)
    nonisolated func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        MainActor.assumeIsolated {
            handleTap(
                preference: UIPencilInteraction.preferredTapAction,
                isEnabled: AppSettings.isPencilDoubleTapEnabled(in: defaults)
            )
        }
    }

    @available(iOS 17.5, *)
    nonisolated func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        MainActor.assumeIsolated {
            handleSqueeze(
                phase: squeeze.phase,
                preference: UIPencilInteraction.preferredSqueezeAction,
                isEnabled: AppSettings.isPencilSqueezeEnabled(in: defaults)
            )
        }
    }
}
