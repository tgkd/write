import SwiftUI
import WidgetKit

struct DailyKanjiEntryView: View {
    let entry: DailyKanjiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        familyView
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily Kanji")
            .accessibilityValue(accessibilitySummary)
            .accessibilityHint("Opens practice for this kanji.")
            .widgetURL(PracticeLink.url(codePoint: entry.kanji.codePoint))
    }

    private var accessibilitySummary: String {
        let kanji = entry.kanji
        let parts: [String?] = [
            kanji.character,
            kanji.meanings.isEmpty ? nil : kanji.meanings.joined(separator: ", "),
            kanji.onYomi,
            kanji.kunYomi,
            kanji.strokeCountLabel
        ]
        return parts.compactMap { $0 }.joined(separator: ", ")
    }

    @ViewBuilder
    private var familyView: some View {
        switch family {
        case .systemMedium:
            MediumDailyKanjiView(kanji: entry.kanji)
        case .accessoryRectangular:
            RectangularDailyKanjiView(kanji: entry.kanji)
        case .accessoryCircular:
            CircularDailyKanjiView(kanji: entry.kanji)
        default:
            SmallDailyKanjiView(kanji: entry.kanji)
        }
    }
}
