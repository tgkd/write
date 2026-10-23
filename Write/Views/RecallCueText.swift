import SwiftUI

struct RecallCueText: View {
    let cue: RecallCue
    var alignment: HorizontalAlignment = .leading
    var primaryFont: Font = .body
    var secondaryFont: Font = .caption

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            ForEach(cue.primary, id: \.self) { line in
                Text(line.text)
                    .font(primaryFont)
                    .foregroundStyle(primaryStyle(for: line.kind))
            }
            ForEach(cue.secondary, id: \.self) { line in
                Text(line.text)
                    .font(secondaryFont)
                    .foregroundStyle(secondaryStyle(for: line.kind))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recallCue")
    }

    private func primaryStyle(for kind: RecallCue.Kind) -> HierarchicalShapeStyle {
        switch kind {
        case .kunYomi:
            return .secondary
        case .romaji, .onYomi, .meanings:
            return .primary
        }
    }

    private func secondaryStyle(for kind: RecallCue.Kind) -> HierarchicalShapeStyle {
        switch kind {
        case .kunYomi, .meanings:
            return .tertiary
        case .romaji, .onYomi:
            return .secondary
        }
    }
}
