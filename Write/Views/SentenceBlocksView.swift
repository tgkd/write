import SwiftUI

struct SentenceBlocksView: View {
    let item: SentencePracticeState.Item
    let completedCharacters: Set<Int>
    let currentCharacter: Int?
    @ObservedObject var slotState: PracticeState

    private let boxSize: CGFloat = 56

    var body: some View {
        WordFlowLayout(spacing: 14, lineSpacing: 12) {
            ForEach(groups, id: \.self) { group in
                HStack(spacing: 4) {
                    ForEach(group, id: \.self) { blockIndex in
                        blockView(item.blocks[blockIndex])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sentenceBlocks")
    }

    private var groups: [[Int]] {
        var result: [[Int]] = []
        for (index, block) in item.blocks.enumerated() {
            if block.isPunctuation, !result.isEmpty {
                result[result.count - 1].append(index)
            } else {
                result.append([index])
            }
        }
        return result
    }

    private func blockView(_ block: SentencePracticeState.Block) -> some View {
        HStack(spacing: 4) {
            ForEach(block.cells, id: \.characterIndex) { cell in
                cellView(cell)
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: SentencePracticeState.Cell) -> some View {
        if cell.isWritten {
            writtenCell(cell)
        } else {
            Text(String(cell.character))
                .font(.system(size: boxSize * 0.62))
                .frame(minWidth: boxSize * 0.5, minHeight: boxSize)
                .accessibilityLabel(String(cell.character))
                .accessibilityIdentifier("sentenceCell.\(cell.characterIndex)")
        }
    }

    private func writtenCell(_ cell: SentencePracticeState.Cell) -> some View {
        let isCompleted = completedCharacters.contains(cell.characterIndex)
        let isCurrent = currentCharacter == cell.characterIndex
        let isRevealed = isCompleted || (isCurrent && !slotState.hidesCharacter)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrent ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? Color.accentColor : Color(.systemGray4), lineWidth: isCurrent ? 2 : 1)
            if isRevealed {
                Text(String(cell.character))
                    .font(.system(size: boxSize * 0.62))
                    .foregroundStyle(isCompleted ? Color.primary : Color.secondary)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(width: boxSize, height: boxSize)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isRevealed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(cell: cell, isRevealed: isRevealed, isCurrent: isCurrent))
        .accessibilityIdentifier("sentenceCell.\(cell.characterIndex)")
    }

    private func accessibilityLabel(cell: SentencePracticeState.Cell, isRevealed: Bool, isCurrent: Bool) -> String {
        if isRevealed {
            return String(cell.character)
        }
        return isCurrent ? String(localized: "Current character slot") : String(localized: "Empty character slot")
    }
}
