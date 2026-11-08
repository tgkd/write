import SwiftUI

struct AnswerGlyph: View {
    let kanji: KanjiData
    let isHidden: Bool
    let fontSize: CGFloat

    var body: some View {
        if isHidden {
            VStack(spacing: 4) {
                Text("?")
                    .font(.system(size: fontSize * 0.6, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: fontSize * 1.25, height: fontSize * 1.25)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .accessibilityLabel("Hidden character")
                    .accessibilityIdentifier("hiddenGlyph")
                if kanji.script != .kanji {
                    Text(kanji.script.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text(kanji.text)
                .font(.system(size: fontSize))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(width: kanji.text.count > 1 ? fontSize : nil)
                .accessibilityIdentifier("answerGlyph")
        }
    }
}
