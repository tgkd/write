import SwiftUI

struct NotebookViewRepresentable: UIViewControllerRepresentable {
    let kanjiList: [KanjiData]
    @EnvironmentObject private var settings: AppSettings

    func makeUIViewController(context: Context) -> UINavigationController {
        let settingsObj = settings
        let state = NotebookState(kanjiList: kanjiList, cellsPerRow: settingsObj.cellsPerRow)
        context.coordinator.notebookState = state

        let vc = NotebookViewController()
        vc.notebookState = state
        vc.sourceKanji = kanjiList
        vc.showCrosshair = settingsObj.showCrosshairGuidelines
        vc.allowedTouchTypes = settingsObj.allowedTouchTypes
        vc.pressureSensitivity = settingsObj.pressureSensitivity
        vc.title = "Notebook"

        context.coordinator.viewController = vc

        let nav = UINavigationController(rootViewController: vc)
        nav.navigationBar.prefersLargeTitles = false
        return nav
    }

    func updateUIViewController(_ nav: UINavigationController, context: Context) {
        guard let vc = context.coordinator.viewController else { return }
        let settingsObj = settings
        vc.applySettingsUpdate(
            showCrosshair: settingsObj.showCrosshairGuidelines,
            allowedTouchTypes: settingsObj.allowedTouchTypes,
            pressureSensitivity: settingsObj.pressureSensitivity,
            cellsPerRow: settingsObj.cellsPerRow
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        var notebookState: NotebookState?
        weak var viewController: NotebookViewController?
    }
}
