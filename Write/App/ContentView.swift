import SwiftUI

struct ContentView: View {
    private let dataStore = KanjiDataStore()

    var body: some View {
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
}
