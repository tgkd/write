import SwiftUI
import WidgetKit

struct CircularDailyKanjiView: View {
    let kanji: DailyKanji

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(kanji.character)
                .font(.system(size: 30))
                .widgetAccentable()
        }
        .modifier(WidgetBackground())
    }
}
