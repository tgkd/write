import SwiftUI

struct SentencePracticeView: View {
    let prompts: [WordPrompt]
    let dataStore: KanjiDataStore

    var body: some View {
        Text(verbatim: prompts.first?.id ?? "")
    }
}
