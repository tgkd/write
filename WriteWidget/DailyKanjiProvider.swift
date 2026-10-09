import WidgetKit

struct DailyKanjiProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyKanjiEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyKanjiEntry) -> Void) {
        let now = Date.now
        guard let kanji = makePicker().kanji(for: now) else {
            completion(.placeholder)
            return
        }
        completion(DailyKanjiEntry(date: now, kanji: kanji))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyKanjiEntry>) -> Void) {
        let picker = makePicker()
        let entries = picker.timelineDates(from: .now, days: 7).map { date in
            DailyKanjiEntry(date: date, kanji: picker.kanji(for: date) ?? DailyKanjiEntry.placeholder.kanji)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makePicker() -> DailyKanjiPicker {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return DailyKanjiPicker(entries: DailyKanjiCatalog.load(from: .main), calendar: calendar)
    }
}
