import UIKit

@MainActor
enum Haptics {
    enum Event {
        case unitCompleted
        case runCompleted
    }

    static func play(_ event: Event, on view: UIView? = nil) {
        switch event {
        case .unitCompleted:
            lightImpact(on: view)
        case .runCompleted:
            success(on: view)
        }
    }

    private static func attachedView(preferring view: UIView?) -> UIView? {
        if let view, view.window != nil {
            return view
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func lightImpact(on view: UIView?) {
        if #available(iOS 17.5, *), let view = attachedView(preferring: view) {
            UIImpactFeedbackGenerator(style: .light, view: view).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private static func success(on view: UIView?) {
        if #available(iOS 17.5, *), let view = attachedView(preferring: view) {
            UINotificationFeedbackGenerator(view: view).notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
