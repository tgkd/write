import Foundation

final class WordPromptStore: Sendable {
    let prompts: [WordPrompt]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "word_prompts", withExtension: "json") else {
            assertionFailure("word_prompts.json not found in bundle")
            prompts = []
            return
        }
        do {
            prompts = try WordPromptStore.decode(Data(contentsOf: url))
        } catch {
            assertionFailure("Failed to load word prompts: \(error)")
            prompts = []
        }
    }

    init(prompts: [WordPrompt]) {
        self.prompts = prompts
    }

    static func decode(_ data: Data) throws -> [WordPrompt] {
        try JSONDecoder().decode([WordPrompt].self, from: data)
    }

    func prompts(for route: WordSessionRoute) -> [WordPrompt] {
        route.promptIDs.compactMap { id in prompts.first { $0.id == id } }
    }

    func randomPromptIDs(count: Int) -> [String] {
        Array(prompts.shuffled().prefix(count)).map(\.id)
    }

    var sentencePrompts: [WordPrompt] {
        prompts.filter { $0.tokens?.isEmpty == false && $0.translation != nil }
    }

    var writingPrompts: [WordPrompt] {
        sentencePrompts.filter { prompt in
            prompt.presentation?.validatedGroups(tokenCount: prompt.tokens?.count ?? 0) != nil
        }
    }

    func prompts(for route: WritingRoute) -> [WordPrompt] {
        route.promptIDs.compactMap { id in writingPrompts.first { $0.id == id } }
    }

    func randomWritingPromptIDs(count: Int, mode: WritingMode) -> [String] {
        Array(writingPrompts.filter { mode != .empty || $0.presentation?.allowsEmpty == true }.shuffled().prefix(count)).map(\.id)
    }
}
