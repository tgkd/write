import SwiftUI

struct KanjiPickerView: View {
    let dataStore: KanjiDataStore
    private let allKanji: [KanjiData]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private static let jlptLevels = [5, 4, 3, 2, 1]

    @EnvironmentObject private var settings: AppSettings
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var selectedJLPT: Int? = nil

    init(dataStore: KanjiDataStore) {
        self.dataStore = dataStore
        self.allKanji = dataStore.allCodePoints.compactMap { dataStore.lookup(codePoint: $0) }
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

        guard let level = selectedJLPT else { return base }
        return base.filter { $0.jlpt == level }
    }

    var body: some View {
        ScrollView {
            jlptFilterBar
                .padding(.horizontal)
                .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(displayedKanji, id: \.codePoint) { kanji in
                    NavigationLink(value: kanji.codePoint) {
                        Text(String(kanji.character))
                            .font(.system(size: 32))
                            .frame(width: 56, height: 56)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "Search kanji")
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

    private var sessionButton: some View {
        let kanji = dataStore.randomKanji(jlpt: selectedJLPT, count: settings.sessionCount)
        let route = SessionRoute(codePoints: kanji.map(\.codePoint))
        return NavigationLink(value: route) {
            Image(systemName: "play.fill")
        }
        .disabled(kanji.isEmpty)
    }

    private var jlptFilterBar: some View {
        HStack(spacing: 8) {
            filterPill(label: "All", level: nil)
            ForEach(Self.jlptLevels, id: \.self) { level in
                filterPill(label: "N\(level)", level: level)
            }
        }
    }

    private func filterPill(label: String, level: Int?) -> some View {
        let isSelected = selectedJLPT == level
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedJLPT = level
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.primary : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
