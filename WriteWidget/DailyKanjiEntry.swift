import WidgetKit

struct DailyKanjiEntry: TimelineEntry, Sendable {
    let date: Date
    let kanji: DailyKanji

    static let placeholder = DailyKanjiEntry(
        date: .now,
        kanji: DailyKanji(
            codePoint: "5c71",
            character: "山",
            meanings: ["mountain"],
            onYomi: "サン",
            kunYomi: "やま",
            strokeCount: 3,
            jlpt: 5
        )
    )
}
