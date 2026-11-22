import SwiftUI

struct KanjiPickerView: View {
    let dataStore: KanjiDataStore
    let wordPromptStore: WordPromptStore
    private let allKanji: [KanjiData]

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: PracticeHistoryStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var selectedFilter: CharacterFilter = .all
    @State private var levelScheme: CharacterFilter.Scheme = .jlpt
    @State private var pools: (practice: [String], review: [String])?

    @Binding var selectedCodePoint: String?
    private let usesSelectionBinding: Bool
    private let openRoute: ((any Hashable) -> Void)?

    init(
        dataStore: KanjiDataStore,
        wordPromptStore: WordPromptStore,
        selectedCodePoint: Binding<String?>? = nil,
        openRoute: ((any Hashable) -> Void)? = nil
    ) {
        self.dataStore = dataStore
        self.wordPromptStore = wordPromptStore
        self.openRoute = openRoute
        self.allKanji = dataStore.allCodePoints.compactMap { dataStore.lookup(codePoint: $0) }
        if let binding = selectedCodePoint {
            _selectedCodePoint = binding
            usesSelectionBinding = true
        } else {
            _selectedCodePoint = .constant(nil)
            usesSelectionBinding = false
        }
    }

    private var columns: [GridItem] {
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    }

    private var displayedKanji: [KanjiData] {
        let base: [KanjiData]
        if searchText.isEmpty {
            base = allKanji
        } else {
            var results: [KanjiData] = []
            var seen = Set<String>()
            for scalar in searchText.unicodeScalars {
                if let kanji = dataStore.lookup(character: Character(scalar)), !seen.contains(kanji.codePoint) {
                    results.append(kanji)
                    seen.insert(kanji.codePoint)
                }
            }
            for kanji in dataStore.search(query: searchText) where !seen.contains(kanji.codePoint) {
                results.append(kanji)
                seen.insert(kanji.codePoint)
            }
            base = results
        }

        return base.filter { selectedFilter.includes($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                if !usesSelectionBinding {
                    todayHeader
                }
                filterBar
            }
            .padding(.horizontal)
            .padding(.top, 4)

            if searchText.isEmpty {
                sessionStarters
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(displayedKanji, id: \.codePoint) { kanji in
                    kanjiCell(kanji)
                }
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "Search kanji or kana")
        .navigationTitle("Write")
        .navigationBarTitleDisplayMode(usesSelectionBinding ? .automatic : .inline)
        .toolbar {
            if !usesSelectionBinding {
                ToolbarItem(placement: .principal) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    routeLink({ ProgressRoute() }) {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("Progress")
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            if pools == nil {
                pools = computePools()
            }
        }
        .onChange(of: selectedFilter) { _ in
            pools = computePools()
        }
    }

    @ViewBuilder
    private func kanjiCell(_ kanji: KanjiData) -> some View {
        if usesSelectionBinding {
            Button {
                selectedCodePoint = kanji.codePoint
            } label: {
                kanjiCellContent(kanji)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                selectedCodePoint == kanji.codePoint ? Color.accentColor : .clear,
                                lineWidth: 2
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityValue(cellAccessibilityValue(kanji))
            .accessibilityAddTraits(selectedCodePoint == kanji.codePoint ? .isSelected : [])
        } else {
            NavigationLink(value: kanji.codePoint) {
                kanjiCellContent(kanji)
            }
            .buttonStyle(.plain)
            .accessibilityValue(cellAccessibilityValue(kanji))
        }
    }

    private func cellAccessibilityValue(_ kanji: KanjiData) -> String {
        if let meanings = kanji.meanings, !meanings.isEmpty {
            return meanings.prefix(2).joined(separator: ", ")
        }
        return kanji.romaji ?? ""
    }

    private func kanjiCellContent(_ kanji: KanjiData) -> some View {
        let size: CGFloat = usesSelectionBinding ? 40 : 56
        let fontSize: CGFloat = usesSelectionBinding ? 24 : 32
        return Text(kanji.text)
            .font(.system(size: fontSize))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(width: size, height: size)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
    }

    private func routeLink<Label: View>(
        _ route: @escaping () -> any Hashable,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            openRoute?(route())
        } label: {
            label()
        }
    }

    private func computePools() -> (practice: [String], review: [String]) {
        var practice: [String] = []
        var review: [String] = []
        for kanji in allKanji where selectedFilter.includes(kanji) {
            practice.append(kanji.codePoint)
            if dataStore.recallEligibility.isEligible(kanji) {
                review.append(kanji.codePoint)
            }
        }
        return (practice, review)
    }

    private func practiceRoute(focus: PracticeFocus) -> SessionRoute {
        let current = pools ?? computePools()
        return PracticeQueue.route(
            focus: focus,
            practicePool: current.practice,
            reviewPool: current.review,
            records: history.records,
            count: settings.sessionCount
        )
    }

    private var todayHeader: some View {
        let today = Date()
        let done = PracticeStats.completedRuns(on: today, in: history.records, calendar: .current)
        return VStack(alignment: .leading, spacing: 2) {
            Text(today.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Group {
                if done == 0 {
                    Text("Ready to write")
                } else {
                    Text("\(done) done today")
                }
            }
            .font(.title.bold())
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.today")
    }

    private var sessionStarters: some View {
        VStack(spacing: 8) {
            practiceCard
            if usesSelectionBinding && DeviceContext.isIPad {
                writingCard
            } else {
                wordsCard
            }
        }
    }

    private var practiceCard: some View {
        let reviewCount = pools.map {
            PracticeQueue.missedCodePoints(pool: $0.review, records: history.records).count
        } ?? 0
        return PracticeSessionCard(
            reviewCount: reviewCount,
            isNewEnabled: pools?.practice.isEmpty != true,
            isReviewEnabled: pools?.review.isEmpty != true,
            startNew: { openRoute?(practiceRoute(focus: .new)) },
            startReview: { openRoute?(practiceRoute(focus: .review)) }
        )
    }

    private var wordsCard: some View {
        routeLink({ WordSessionRoute(promptIDs: wordPromptStore.randomPromptIDs(count: settings.sessionCount)) }) {
            linkCardLabel(title: "Words", systemImage: "character.book.closed.ja")
        }
        .buttonStyle(.plain)
        .disabled(wordPromptStore.prompts.isEmpty)
        .accessibilityIdentifier("session.words")
        .accessibilityInputLabels([Text("Words")])
    }

    private var writingCard: some View {
        routeLink({ WritingRoute(promptIDs: writingPromptIDs()) }) {
            linkCardLabel(title: "Writing", systemImage: "pencil.and.outline")
        }
        .buttonStyle(.plain)
        .disabled(!hasWritingPrompts)
        .accessibilityIdentifier("session.writing")
        .accessibilityInputLabels([Text("Writing")])
    }

    private var uiTestingWritingPromptIDs: [String]? {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestingFreshHistory"),
              let ids = UserDefaults.standard.string(forKey: "uiTestingWritingPromptIDs") else {
            return nil
        }
        return ids.split(separator: ",").map(String.init)
    }

    private var hasWritingPrompts: Bool {
        if let ids = uiTestingWritingPromptIDs {
            return !ids.isEmpty
        }
        let mode = settings.writingMode
        return wordPromptStore.writingPrompts.contains { mode != .empty || $0.presentation?.allowsEmpty == true }
    }

    private func writingPromptIDs() -> [String] {
        if let ids = uiTestingWritingPromptIDs {
            return ids
        }
        return wordPromptStore.randomWritingPromptIDs(count: 5, mode: settings.writingMode)
    }

    private func linkCardLabel(title: LocalizedStringKey, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .lineLimit(cardLineLimit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cardLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CharacterFilter.scriptFilters, id: \.self) { filter in
                    filterPill(filter)
                }
                schemeMenu
                ForEach(levelScheme.levels, id: \.self) { filter in
                    filterPill(filter)
                }
            }
        }
    }

    private var schemeMenu: some View {
        Menu {
            Picker("Levels", selection: schemeSelection) {
                ForEach(CharacterFilter.Scheme.allCases, id: \.self) { scheme in
                    Text(scheme.label).tag(scheme)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(levelScheme.label)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Color(.separator)))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .tint(.primary)
        .accessibilityLabel("Levels")
        .accessibilityValue(levelScheme.label)
        .accessibilityIdentifier("filter.scheme")
    }

    private var schemeSelection: Binding<CharacterFilter.Scheme> {
        Binding {
            levelScheme
        } set: { scheme in
            guard scheme != levelScheme else {
                return
            }
            withAnimation(.easeInOut(duration: 0.15)) {
                levelScheme = scheme
                if selectedFilter.scheme != nil, let first = scheme.levels.first {
                    selectedFilter = first
                }
            }
        }
    }

    private func filterPill(_ filter: CharacterFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.label)
                .font(.subheadline.weight(.medium))
                .fixedSize()
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.primary : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                .clipShape(Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
