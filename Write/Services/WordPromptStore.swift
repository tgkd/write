import Foundation

final class WordPromptStore: Sendable {
    let prompts: [WordPrompt]

    init(bundle: Bundle = .main) {
        prompts = []
    }

    func prompts(for route: WordSessionRoute) -> [WordPrompt] {
        route.promptIDs.compactMap { id in prompts.first { $0.id == id } }
    }

    func randomPromptIDs(count: Int) -> [String] {
        Array(prompts.shuffled().prefix(count)).map(\.id)
    }
}
