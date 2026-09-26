import SwiftUI

struct NavigationGestureGuardRepresentable: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: Controller, coordinator: ()) {
        uiViewController.releaseGuard()
    }

    @MainActor
    final class Controller: UIViewController {
        private let gestureGuard = NavigationGestureGuard()

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            gestureGuard.engage(from: self)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            gestureGuard.release()
        }

        func releaseGuard() {
            gestureGuard.release()
        }
    }
}
