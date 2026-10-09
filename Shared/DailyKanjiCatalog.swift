import Foundation

enum DailyKanjiCatalog {
    static func load(from bundle: Bundle) -> [DailyKanji] {
        guard let url = bundle.url(forResource: "daily_kanji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([DailyKanji].self, from: data) else {
            return []
        }
        return entries
    }
}
