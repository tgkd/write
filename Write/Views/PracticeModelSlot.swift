import SwiftUI

struct PracticeModelSlot: View {
    let kanji: KanjiData
    let isHidden: Bool
    let showsGrid: Bool
    let side: CGFloat

    var body: some View {
        if isHidden {
            VStack(spacing: 4) {
                Text("?")
                    .font(.system(size: side * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Hidden character")
                    .accessibilityIdentifier("hiddenGlyph")
                if kanji.script != .kanji {
                    Text(kanji.script.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        } else {
            PracticeModelView(kanji: kanji, showsGrid: showsGrid)
                .frame(width: side, height: side)
        }
    }
}
