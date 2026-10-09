import SwiftUI

struct RectangularDailyKanjiView: View {
    let kanji: DailyKanji

    var body: some View {
        HStack(spacing: 8) {
            Text(kanji.character)
                .font(.system(size: 34))
            Text(kanji.primaryMeaning)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WidgetBackground())
    }
}
