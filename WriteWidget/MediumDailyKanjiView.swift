import SwiftUI

struct MediumDailyKanjiView: View {
    let kanji: DailyKanji

    var body: some View {
        HStack(spacing: 16) {
            Text(kanji.character)
                .font(.system(size: 80))
            VStack(alignment: .leading, spacing: 4) {
                Text(kanji.meanings.joined(separator: ", "))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let onYomi = kanji.onYomi {
                    Text(onYomi)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let kunYomi = kanji.kunYomi {
                    Text(kunYomi)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text("\(kanji.strokeCountLabel) · JLPT N\(kanji.jlpt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(WidgetBackground())
    }
}
