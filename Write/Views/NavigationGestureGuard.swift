import UIKit

@MainActor
final class NavigationGestureGuard {

    private var disabledRecognizers: [(recognizer: UIGestureRecognizer, wasEnabled: Bool)] = []
    private weak var splitViewController: UISplitViewController?
    private var splitPresentedWithGesture = true

    private var isEngaged: Bool {
        !disabledRecognizers.isEmpty || splitViewController != nil
    }

    func engage(from viewController: UIViewController) {
        guard !isEngaged else { return }

        for ancestor in ancestors(of: viewController) {
            if let navigation = ancestor as? UINavigationController {
                disable(navigation.interactivePopGestureRecognizer)
                if #available(iOS 26.0, *) {
                    disable(navigation.interactiveContentPopGestureRecognizer)
                }
            }
            if splitViewController == nil, let split = ancestor as? UISplitViewController {
                splitViewController = split
                splitPresentedWithGesture = split.presentsWithGesture
                split.presentsWithGesture = false
            }
        }
    }

    func release() {
        for entry in disabledRecognizers {
            entry.recognizer.isEnabled = entry.wasEnabled
        }
        disabledRecognizers.removeAll()

        splitViewController?.presentsWithGesture = splitPresentedWithGesture
        splitViewController = nil
    }

    private func disable(_ recognizer: UIGestureRecognizer?) {
        guard let recognizer,
              !disabledRecognizers.contains(where: { $0.recognizer === recognizer }) else { return }
        disabledRecognizers.append((recognizer, recognizer.isEnabled))
        recognizer.isEnabled = false
    }

    private func ancestors(of viewController: UIViewController) -> [UIViewController] {
        var result: [UIViewController] = []
        func add(_ controller: UIViewController) {
            if !result.contains(where: { $0 === controller }) {
                result.append(controller)
            }
        }

        var parent: UIViewController? = viewController
        while let current = parent {
            add(current)
            parent = current.parent
        }

        var responder: UIResponder? = viewController
        while let current = responder {
            if let controller = current as? UIViewController {
                add(controller)
            }
            responder = current.next
        }
        return result
    }
}
