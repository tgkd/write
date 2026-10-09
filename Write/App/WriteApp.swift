import SwiftUI

@main
struct WriteApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var history = PracticeHistoryStore(directory: WriteApp.historyDirectory)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(history)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                history.retryUnsaved()
            }
        }
    }

    private static var historyDirectory: URL {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestingFreshHistory") else {
            return PracticeHistoryStore.defaultDirectory
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("UITestHistory-\(UUID().uuidString)", isDirectory: true)
    }
}
