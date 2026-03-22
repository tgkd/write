import SwiftUI

struct ContentView: View {
    private let dataStore = KanjiDataStore()
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        NavigationStack {
            KanjiPickerView(dataStore: dataStore)
                .navigationDestination(for: String.self) { codePoint in
                    if let kanji = dataStore.lookup(codePoint: codePoint) {
                        PracticeView(kanjiData: kanji)
                    }
                }
                .navigationDestination(for: SessionRoute.self) { route in
                    let kanji = route.codePoints.compactMap { dataStore.lookup(codePoint: $0) }
                    SessionPracticeView(kanji: kanji)
                }
        }
    }

    // MARK: - iPad

    @State private var selectedCodePoint: String?
    @State private var iPadNavigationPath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            KanjiPickerView(dataStore: dataStore, selectedCodePoint: $selectedCodePoint)
                .navigationDestination(for: SessionRoute.self) { route in
                    let kanji = route.codePoints.compactMap { dataStore.lookup(codePoint: $0) }
                    SessionPracticeView(kanji: kanji)
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
                    iPadPracticeView(kanjiData: kanji)
                }
            }
            .navigationDestination(for: NotebookRoute.self) { route in
                let kanji = route.codePoints.compactMap { dataStore.lookup(codePoint: $0) }
                NotebookViewRepresentable(kanjiList: kanji)
                    .navigationBarBackButtonHidden(true)
            }
            .onChange(of: selectedCodePoint) { _ in
                iPadNavigationPath = NavigationPath()
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
