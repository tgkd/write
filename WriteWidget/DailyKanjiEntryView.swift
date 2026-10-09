import SwiftUI
import WidgetKit

struct DailyKanjiEntryView: View {
    let entry: DailyKanjiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        familyView
            .widgetURL(PracticeLink.url(codePoint: entry.kanji.codePoint))
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
