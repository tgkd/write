import SwiftUI

struct WordSentenceView: View {
    let prompt: WordPrompt

    private struct Token: Identifiable {
        let id: Int
        let text: String
        let isTarget: Bool
        let suffix: String?
    }

    var body: some View {
        WordFlowLayout(spacing: 6, lineSpacing: 10) {
            ForEach(tokens) { token in
                if token.isTarget {
                    targetView(token)
                } else {
                    Text(token.text)
                }
            }
        }
        .font(.title3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prompt.sentence)
        .accessibilityIdentifier("wordPrompt")
    }

    private func targetView(_ token: Token) -> some View {
        HStack(spacing: 2) {
            Text(token.text)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                )
            if let suffix = token.suffix {
                Text(suffix)
            }
        }
    }

    private var tokens: [Token] {
        let beforeWords = words(in: prompt.before)
        var afterWords = words(in: prompt.after)
        var suffix: String?
        if !prompt.after.isEmpty, !prompt.after.hasPrefix(" "), !afterWords.isEmpty {
            suffix = afterWords.removeFirst()
        }
        var result: [Token] = []
        for word in beforeWords {
            result.append(Token(id: result.count, text: word, isTarget: false, suffix: nil))
        }
        result.append(Token(id: result.count, text: prompt.reading, isTarget: true, suffix: suffix))
        for word in afterWords {
            result.append(Token(id: result.count, text: word, isTarget: false, suffix: nil))
        }
        return result
    }

    private func words(in text: String) -> [String] {
        text.split(separator: " ").map(String.init)
    }
}
