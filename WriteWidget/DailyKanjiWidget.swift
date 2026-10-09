import SwiftUI
import WidgetKit

@main
struct DailyKanjiWidget: Widget {
    let kind = "DailyKanjiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyKanjiProvider()) { entry in
            DailyKanjiEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Kanji")
        .description("A new kanji to practice every day.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}
