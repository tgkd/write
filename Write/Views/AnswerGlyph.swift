import SwiftUI

struct AnswerGlyph: View {
    let kanji: KanjiData
    let isHidden: Bool
    let fontSize: CGFloat
    let onReveal: () -> Void

    var body: some View {
        if isHidden {
            VStack(spacing: 4) {
                Button(action: onReveal) {
                    VStack(spacing: 2) {
                        Image(systemName: "eye")
                            .font(.system(size: fontSize * 0.35))
                        Text("Reveal")
                            .font(.caption2)
                    }
                    .frame(width: fontSize * 1.25, height: fontSize * 1.25)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reveal answer")
                if kanji.script != .kanji {
                    Text(kanji.script.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text(String(kanji.character))
                .font(.system(size: fontSize))
                .accessibilityIdentifier("answerGlyph")
        }
    }
}
