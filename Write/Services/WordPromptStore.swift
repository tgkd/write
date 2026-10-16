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
}
