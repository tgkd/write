import SwiftUI

struct WordSlotsRow: View {
    let prompt: WordPrompt
    let completedSegments: Set<Int>
    let currentSegment: Int?
    @ObservedObject var slotState: PracticeState

    private let boxSize: CGFloat = 56

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(Array(prompt.segments.enumerated()), id: \.offset) { index, segment in
                segmentView(index: index, segment: segment)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wordSlots")
    }

    @ViewBuilder
    private func segmentView(index: Int, segment: WordPrompt.Segment) -> some View {
        switch segment {
        case .kana(let text):
            Text(text)
                .font(.system(size: boxSize * 0.62))
                .accessibilityLabel(text)
        case .kanji(let text):
            slotBox(index: index, text: text)
        }
    }

    private func slotBox(index: Int, text: String) -> some View {
        let isCompleted = completedSegments.contains(index)
        let isCurrent = currentSegment == index
        let isRevealed = isCompleted || (isCurrent && !slotState.hidesCharacter)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrent ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? Color.accentColor : Color(.systemGray4), lineWidth: isCurrent ? 2 : 1)
            if isRevealed {
                Text(text)
                    .font(.system(size: boxSize * 0.62))
                    .foregroundStyle(isCompleted ? Color.primary : Color.secondary)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(width: boxSize, height: boxSize)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isRevealed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(text: text, isRevealed: isRevealed, isCurrent: isCurrent))
        .accessibilityIdentifier("wordSlot.\(index)")
    }

    private func accessibilityLabel(text: String, isRevealed: Bool, isCurrent: Bool) -> String {
        if isRevealed {
            return text
        }
        return isCurrent ? String(localized: "Current kanji slot") : String(localized: "Empty kanji slot")
    }
}
