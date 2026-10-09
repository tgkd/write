import SwiftUI

struct SmallDailyKanjiView: View {
    let kanji: DailyKanji

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kanji.character)
                .font(.system(size: 64))
            Text(kanji.primaryMeaning)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(kanji.strokeCountLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(WidgetBackground())
    }
}
