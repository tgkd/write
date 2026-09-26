import SwiftUI

struct KanjiPickerView: View {
    let dataStore: KanjiDataStore
    private let allKanji: [KanjiData]

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var selectedFilter: CharacterFilter = .all

    @Binding var selectedCodePoint: String?
    private let usesSelectionBinding: Bool

    init(dataStore: KanjiDataStore, selectedCodePoint: Binding<String?>? = nil) {
        self.dataStore = dataStore
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
            jlptFilterBar
                .padding(.horizontal)
                .padding(.top, 4)

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
                    sessionButton
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

    private var sessionButton: some View {
        let kanji = dataStore.randomCharacters(matching: selectedFilter, count: settings.sessionCount)
        let route = SessionRoute(codePoints: kanji.map(\.codePoint))
        return NavigationLink(value: route) {
            Image(systemName: "play.fill")
        }
        .disabled(kanji.isEmpty)
    }

    private var jlptFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CharacterFilter.pickerOrder, id: \.self) { filter in
                    filterPill(filter)
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
