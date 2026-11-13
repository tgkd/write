import StoreKit
import SwiftUI

struct ContentView: View {
    private let dataStore = KanjiDataStore()
    private let wordPromptStore = WordPromptStore()
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Group {
            if usesSplitShell {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onOpenURL { openPracticeLink($0) }
        .onChange(of: iPhonePath.count) { requestPendingReview(pathIsEmpty: $0 == 0) }
        .onChange(of: iPadNavigationPath.count) { requestPendingReview(pathIsEmpty: $0 == 0) }
    }

    private func requestPendingReview(pathIsEmpty: Bool) {
        guard pathIsEmpty, settings.isReviewRequestPending else { return }
        settings.isReviewRequestPending = false
        let requestReview = requestReview
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            requestReview()
        }
    }

    private var usesSplitShell: Bool {
        if sizeClass == .regular {
            return true
        }
        guard #available(iOS 17, *) else {
            return false
        }
        return DeviceContext.isIPad && !iPadNavigationPath.isEmpty
    }

    private func openPracticeLink(_ url: URL) {
        guard let linkedCodePoint = PracticeLink.codePoint(from: url),
              let kanji = dataStore.lookup(codePoint: linkedCodePoint) else {
            return
        }
        let route = PracticeRoute(codePoint: kanji.codePoint, origin: .widget)
        if usesSplitShell {
            selectedCodePoint = route.codePoint
            iPadNavigationPath = NavigationPath([route])
        } else {
            iPhonePath = NavigationPath([route])
        }
    }

    // MARK: - iPhone

    @State private var iPhonePath = NavigationPath()

    private var iPhoneLayout: some View {
        NavigationStack(path: $iPhonePath) {
            KanjiPickerView(dataStore: dataStore, wordPromptStore: wordPromptStore, openRoute: { iPhonePath.append($0) })
                .navigationDestination(for: String.self) { codePoint in
                    if let kanji = dataStore.lookup(codePoint: codePoint) {
                        PracticeView(kanjiData: kanji, mode: settings.practiceMode, context: RunContext(origin: .grid))
                            .id(codePoint)
                    }
                }
                .navigationDestination(for: PracticeRoute.self) { route in
                    if let kanji = dataStore.lookup(codePoint: route.codePoint) {
                        PracticeView(kanjiData: kanji, mode: settings.practiceMode, context: RunContext(origin: route.origin))
                            .id(route.codePoint)
                    }
                }
                .navigationDestination(for: SessionRoute.self) { route in
                    SessionPracticeView(kanji: dataStore.queue(for: route), kind: route.kind, origin: route.origin)
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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var sidebarSelection: Binding<String?> {
        Binding(
            get: { selectedCodePoint },
            set: { newValue in
                iPadNavigationPath = NavigationPath()
                selectedCodePoint = newValue
            }
        )
    }

    private func openInDetail(_ route: any Hashable) {
        var path = NavigationPath()
        path.append(route)
        iPadNavigationPath = path
    }

    @ViewBuilder
    private func splitShell<Sidebar: View, Detail: View>(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) -> some View {
        if #available(iOS 17, *) {
            NavigationSplitView(
                columnVisibility: $columnVisibility,
                preferredCompactColumn: .constant(.detail),
                sidebar: sidebar,
                detail: detail
            )
        } else {
            NavigationSplitView(columnVisibility: $columnVisibility, sidebar: sidebar, detail: detail)
        }
    }

    private var iPadLayout: some View {
        splitShell {
            KanjiPickerView(
                dataStore: dataStore,
                wordPromptStore: wordPromptStore,
                selectedCodePoint: sidebarSelection,
                openRoute: openInDetail
            )
            .removingSystemSidebarToggle()
        } detail: {
            NavigationStack(path: $iPadNavigationPath) {
                Group {
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
                .modifier(SidebarToggleToolbar(columnVisibility: $columnVisibility))
                .navigationDestination(for: PracticeRoute.self) { route in
                    if let kanji = dataStore.lookup(codePoint: route.codePoint) {
                        iPadPracticeView(kanjiData: kanji, mode: settings.practiceMode, context: RunContext(origin: route.origin))
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
                .navigationDestination(for: SessionRoute.self) { route in
                    SessionPracticeView(kanji: dataStore.queue(for: route), kind: route.kind, origin: route.origin)
                        .modifier(SidebarToggleToolbar(columnVisibility: $columnVisibility))
                }
                .navigationDestination(for: WritingRoute.self) { route in
                    WritingView(prompts: wordPromptStore.prompts(for: route), dataStore: dataStore, mode: settings.writingMode)
                        .modifier(SidebarToggleToolbar(columnVisibility: $columnVisibility))
                }
                .navigationDestination(for: ProgressRoute.self) { _ in
                    PracticeProgressView(dataStore: dataStore)
                        .modifier(SidebarToggleToolbar(columnVisibility: $columnVisibility))
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct PracticeRoute: Hashable {
    let codePoint: String
    var origin: RunOrigin = .grid
}

struct NotebookRoute: Hashable {
    let codePoints: [String]
}

struct ProgressRoute: Hashable {}
