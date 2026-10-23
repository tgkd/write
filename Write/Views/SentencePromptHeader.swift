import SwiftUI

struct SentencePromptHeader: View {
    let item: SentencePracticeState.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.kanaSentence)
                .font(.title2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("sentencePrompt")

            if let translation = item.prompt.translation {
                Text(translation)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("sentenceTranslation")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
