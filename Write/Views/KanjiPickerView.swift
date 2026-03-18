import SwiftUI

struct KanjiPickerView: View {
    let dataStore: KanjiDataStore
    private let allKanji: [KanjiData]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    @State private var searchText = ""
    @State private var showSettings = false

    init(dataStore: KanjiDataStore) {
        self.dataStore = dataStore
        self.allKanji = dataStore.allCodePoints.compactMap { dataStore.lookup(codePoint: $0) }
    }

    private var displayedKanji: [KanjiData] {
        if searchText.isEmpty {
            return allKanji
        }
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
        return results
    }

    var body: some View {
        ScrollView {
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
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
