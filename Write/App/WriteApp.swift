import SwiftUI

@main
struct WriteApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var history = PracticeHistoryStore(directory: WriteApp.historyDirectory)
    @StateObject private var wordHistory = WordHistoryStore(directory: WriteApp.wordHistoryDirectory)
    @StateObject private var historySync = HistorySyncController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(history)
                .environmentObject(wordHistory)
                .environmentObject(historySync)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                history.retryUnsaved()
                historySync.sceneBecameActive(history: history, enabled: settings.iCloudSyncEnabled)
            }
        }
    }

    private static var wordHistoryDirectory: URL {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestingFreshHistory") else {
            return WordHistoryStore.defaultDirectory
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("UITestWordHistory-\(UUID().uuidString)", isDirectory: true)
    }

    private static var historyDirectory: URL {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestingFreshHistory") else {
            return PracticeHistoryStore.defaultDirectory
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("UITestHistory-\(UUID().uuidString)", isDirectory: true)
    }
}
