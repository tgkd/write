import SwiftUI

struct ContentView: View {
    private let dataStore = KanjiDataStore()
    private let wordPromptStore = WordPromptStore()
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onOpenURL { openPracticeLink($0) }
    }

    private func openPracticeLink(_ url: URL) {
        guard let linkedCodePoint = PracticeLink.codePoint(from: url),
              let kanji = dataStore.lookup(codePoint: linkedCodePoint) else {
            return
        }
        let codePoint = kanji.codePoint
        if sizeClass == .regular {
            selectedCodePoint = codePoint
            iPadNavigationPath = NavigationPath([PracticeRoute(codePoint: codePoint)])
        } else {
            iPhonePath = NavigationPath([codePoint])
        }
    }

    // MARK: - iPhone

    @State private var iPhonePath = NavigationPath()

    private var iPhoneLayout: some View {
        NavigationStack(path: $iPhonePath) {
            KanjiPickerView(dataStore: dataStore, wordPromptStore: wordPromptStore)
                .navigationDestination(for: String.self) { codePoint in
                    if let kanji = dataStore.lookup(codePoint: codePoint) {
                        PracticeView(kanjiData: kanji, mode: settings.practiceMode)
                            .id(codePoint)
                    }
                }
                .navigationDestination(for: SessionRoute.self) { route in
                    SessionPracticeView(kanji: dataStore.queue(for: route), kind: route.kind)
                }
                .navigationDestination(for: WordSessionRoute.self) { route in
                    WordPracticeView(prompts: wordPromptStore.prompts(for: route), dataStore: dataStore)
                }
                .navigationDestination(for: ProgressRoute.self) { _ in
                    PracticeProgressView(dataStore: dataStore)
                }
        }
    }

    // MARK: - iPad

    @State private var selectedCodePoint: String?
    @State private var iPadNavigationPath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var sidebarSelection: Binding<String?> {
        Binding(
            get: { selectedCodePoint },
            set: { newValue in
                if newValue != selectedCodePoint {
                    iPadNavigationPath = NavigationPath()
                }
                selectedCodePoint = newValue
            }
        )
    }

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            KanjiPickerView(dataStore: dataStore, wordPromptStore: wordPromptStore, selectedCodePoint: sidebarSelection)
                .navigationDestination(for: SessionRoute.self) { route in
                    SessionPracticeView(kanji: dataStore.queue(for: route), kind: route.kind)
                }
                .navigationDestination(for: WordSessionRoute.self) { route in
                    WordPracticeView(prompts: wordPromptStore.prompts(for: route), dataStore: dataStore)
                }
                .navigationDestination(for: ProgressRoute.self) { _ in
                    PracticeProgressView(dataStore: dataStore)
                }
        } detail: {
            NavigationStack(path: $iPadNavigationPath) {
                if let codePoint = selectedCodePoint,
                   let kanji = dataStore.lookup(codePoint: codePoint) {
                    KanjiDetailView(
                        kanji: kanji,
                        onPractice: {
                            iPadNavigationPath.append(PracticeRoute(codePoint: codePoint))
                        },
                        onNotebook: {
                            iPadNavigationPath.append(NotebookRoute(codePoints: [codePoint]))
                            columnVisibility = .detailOnly
                        }
                    )
                } else {
                    Text("Select a kanji")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationDestination(for: PracticeRoute.self) { route in
                if let kanji = dataStore.lookup(codePoint: route.codePoint) {
                    iPadPracticeView(kanjiData: kanji, mode: settings.practiceMode)
                        .id(route.codePoint)
                        .modifier(SidebarToggleToolbar(columnVisibility: $columnVisibility))
                }
            }
            .navigationDestination(for: NotebookRoute.self) { route in
                let kanji = route.codePoints.compactMap { dataStore.lookup(codePoint: $0) }
                NotebookViewRepresentable(kanjiList: kanji)
                    .navigationBarBackButtonHidden(true)
                    .modifier(SidebarToggleToolbar(columnVisibility: $columnVisibility))
            }
        }
    }
}

struct PracticeRoute: Hashable {
    let codePoint: String
}

struct NotebookRoute: Hashable {
    let codePoints: [String]
}

struct ProgressRoute: Hashable {}
