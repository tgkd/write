import SwiftUI

struct KanjiPickerView: View {
    let dataStore: KanjiDataStore
    let wordPromptStore: WordPromptStore
    private let allKanji: [KanjiData]

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: PracticeHistoryStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var selectedFilter: CharacterFilter = .all
    @State private var levelScheme: CharacterFilter.Scheme = .jlpt

    @Binding var selectedCodePoint: String?
    private let usesSelectionBinding: Bool

    init(dataStore: KanjiDataStore, wordPromptStore: WordPromptStore, selectedCodePoint: Binding<String?>? = nil) {
        self.dataStore = dataStore
        self.wordPromptStore = wordPromptStore
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
            filterBar
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    NavigationLink(value: ProgressRoute()) {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("Progress")
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
        } else {
            NavigationLink(value: kanji.codePoint) {
                kanjiCellContent(kanji)
            }
            .buttonStyle(.plain)
        }
    }

    private func kanjiCellContent(_ kanji: KanjiData) -> some View {
        let size: CGFloat = usesSelectionBinding ? 40 : 56
        let fontSize: CGFloat = usesSelectionBinding ? 24 : 32
        return Text(String(kanji.character))
            .font(.system(size: fontSize))
            .frame(width: size, height: size)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
    }

    private var sessionStarters: some View {
        let practice = dataStore.randomCharacters(matching: selectedFilter, count: settings.sessionCount)
        let recall = dataStore.randomCharacters(matching: selectedFilter, count: settings.sessionCount, forRecall: true)
        let review = PracticeStats.reviewItems(from: history.records)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                sessionCard(
                    title: "Practice",
                    subtitle: "\(practice.count) random · \(settings.practiceMode.displayName)",
                    systemImage: "pencil.tip",
                    route: SessionRoute(codePoints: practice.map(\.codePoint), kind: .practice),
                    identifier: "session.practice"
                )
                sessionCard(
                    title: "Recall",
                    subtitle: "\(recall.count) random · from memory",
                    systemImage: "brain.head.profile",
                    route: SessionRoute(codePoints: recall.map(\.codePoint), kind: .recall),
                    identifier: "session.recall"
                )
            }
            if !review.isEmpty {
                reviewCard(review)
            }
            wordsCard
        }
    }

    private var wordsCard: some View {
        let route = WordSessionRoute(promptIDs: wordPromptStore.randomPromptIDs(count: settings.sessionCount))
        return NavigationLink(value: route) {
            HStack(spacing: 6) {
                Image(systemName: "character.book.closed.ja")
                    .foregroundStyle(Color.accentColor)
                Text("Words")
                    .font(.headline)
                Text("write the missing kanji")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(route.promptIDs.isEmpty)
        .accessibilityIdentifier("session.words")
    }

    private func sessionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        route: SessionRoute,
        identifier: String
    ) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.accentColor)
                    Text(title)
                }
                .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(route.codePoints.isEmpty)
        .accessibilityIdentifier(identifier)
    }

    private func reviewCard(_ review: [PracticeStats.ReviewItem]) -> some View {
        NavigationLink(value: SessionRoute.review(review, count: settings.sessionCount)) {
            HStack(spacing: 6) {
                Image(systemName: "repeat")
                    .foregroundStyle(Color.accentColor)
                Text("Review")
                    .font(.headline)
                Text("\(review.count) to recall again")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("session.review")
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
            }
            .font(.subheadline.weight(.medium))
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Color(.separator)))
        }
        .tint(.primary)
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
        }
        .buttonStyle(.plain)
    }
}
