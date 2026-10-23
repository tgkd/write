import Combine
import Foundation

@MainActor
final class SentencePracticeState: ObservableObject {
    static let cueProfile = "kana-sentence+en-translation/blocks"

    struct Cell: Equatable {
        let characterIndex: Int
        let character: Character
        let kanjiData: KanjiData?

        var isWritten: Bool {
            kanjiData != nil
        }
    }

    struct Block: Equatable {
        let token: SentenceToken
        let cells: [Cell]

        var kana: String {
            token.reading ?? token.surface
        }

        var isPunctuation: Bool {
            !token.surface.isEmpty && token.surface.allSatisfy { $0.isPunctuation || $0.isWhitespace }
        }
    }

    struct Item: Equatable {
        let prompt: WordPrompt
        let blocks: [Block]
        let writable: [Cell]

        var cells: [Cell] {
            blocks.flatMap(\.cells)
        }

        var writtenSentence: String {
            blocks.map(\.token.surface).joined()
        }

        var kanaSentence: String {
            var text = ""
            for block in blocks {
                if !text.isEmpty && !block.isPunctuation {
                    text += " "
                }
                text += block.kana
            }
            return text
        }
    }

    struct SentenceResult: Equatable {
        let prompt: WordPrompt
        let sentence: String
        let kana: String
        let misses: Int
        let hintsUsed: Int
        let cellCount: Int
    }

    let sessionID = UUID()
    let items: [Item]
    @Published private(set) var promptIndex = 0
    @Published private(set) var cellIndex = 0
    @Published private(set) var slotState: PracticeState?
    @Published private(set) var isSentenceComplete = false
    @Published private(set) var isSessionComplete: Bool
    @Published private(set) var results: [SentenceResult] = []

    var validationConfig: ValidationConfig {
        didSet {
            slotState?.validationConfig = validationConfig
        }
    }

    var onSentenceCompleted: ((WordRecord) -> Void)?

    private(set) var slotRun = 0
    private var slotRecords: [WordSlotRecord] = []

    init(prompts: [WordPrompt], lookup: (Character) -> KanjiData?, config: ValidationConfig = .standard) {
        items = prompts.compactMap { prompt in
            SentencePracticeState.item(for: prompt, lookup: lookup)
        }
        validationConfig = config
        isSessionComplete = items.isEmpty
        slotState = makeSlotState()
    }

    convenience init(prompts: [WordPrompt], dataStore: KanjiDataStore, config: ValidationConfig = .standard) {
        self.init(prompts: prompts, lookup: { dataStore.lookup(character: $0) }, config: config)
    }

    private static func item(for prompt: WordPrompt, lookup: (Character) -> KanjiData?) -> Item? {
        guard let tokens = prompt.tokens, !tokens.isEmpty else {
            return nil
        }
        var characterIndex = 0
        var blocks: [Block] = []
        for token in tokens {
            var cells: [Cell] = []
            for character in token.surface {
                let data = lookup(character).flatMap { $0.strokes.isEmpty ? nil : $0 }
                cells.append(Cell(characterIndex: characterIndex, character: character, kanjiData: data))
                characterIndex += 1
            }
            blocks.append(Block(token: token, cells: cells))
        }
        let writable = blocks.flatMap(\.cells).filter(\.isWritten)
        guard !writable.isEmpty else {
            return nil
        }
        return Item(prompt: prompt, blocks: blocks, writable: writable)
    }

    var currentItem: Item? {
        guard !isSessionComplete, items.indices.contains(promptIndex) else {
            return nil
        }
        return items[promptIndex]
    }

    var currentPrompt: WordPrompt? {
        currentItem?.prompt
    }

    var currentCell: Cell? {
        guard let item = currentItem, item.writable.indices.contains(cellIndex) else {
            return nil
        }
        return item.writable[cellIndex]
    }

    var currentCharacterIndex: Int? {
        guard !isSentenceComplete else {
            return nil
        }
        return currentCell?.characterIndex
    }

    var completedCharacterIndices: Set<Int> {
        guard let item = currentItem else {
            return []
        }
        let filled = item.cells.filter { !$0.isWritten }.map(\.characterIndex)
        let count = isSentenceComplete ? item.writable.count : cellIndex
        let written = item.writable.prefix(count).map(\.characterIndex)
        return Set(filled + written)
    }

    var progress: (current: Int, total: Int) {
        (min(promptIndex + 1, items.count), items.count)
    }

    var isLastSentence: Bool {
        promptIndex + 1 >= items.count
    }

    func advanceSentence() {
        guard isSentenceComplete else {
            return
        }
        guard promptIndex + 1 < items.count else {
            isSessionComplete = true
            slotState = nil
            return
        }
        promptIndex += 1
        startSentence()
    }

    func restartSentence() {
        guard !isSentenceComplete, currentItem != nil else {
            return
        }
        startSentence()
    }

    private func startSentence() {
        cellIndex = 0
        slotRecords = []
        isSentenceComplete = false
        slotState = makeSlotState()
    }

    private func makeSlotState() -> PracticeState? {
        guard let kanjiData = currentCell?.kanjiData else {
            return nil
        }
        let state = PracticeState(
            kanjiData: kanjiData,
            isRecall: true,
            config: validationConfig,
            context: RunContext(sessionID: sessionID, origin: nil, slot: promptIndex)
        )
        slotRun += 1
        state.onRunCompleted = { [weak self, weak state] record in
            guard let self, let state else {
                return
            }
            self.slotDidComplete(state, record: record)
        }
        return state
    }

    private func slotDidComplete(_ state: PracticeState, record: PracticeRecord) {
        guard state === slotState, !isSentenceComplete, let item = currentItem, let cell = currentCell else {
            return
        }
        slotRecords.append(WordSlotRecord(segmentIndex: cell.characterIndex, record: record))
        guard cellIndex + 1 >= item.writable.count else {
            cellIndex += 1
            slotState = makeSlotState()
            return
        }
        finishSentence(item)
    }

    private func finishSentence(_ item: Item) {
        let slotRuns = slotRecords.map(\.record)
        let misses = slotRuns.reduce(0) { $0 + $1.misses }
        let hintsUsed = slotRuns.filter(\.revealed).count
        let completedAt = slotRuns.last?.completedAt ?? Date()
        let record = WordRecord(
            id: UUID(),
            promptID: item.prompt.id,
            startedAt: slotRuns.first?.startedAt ?? completedAt,
            completedAt: completedAt,
            misses: misses,
            hintsUsed: hintsUsed,
            slotCount: item.writable.count,
            sessionID: sessionID,
            promptRevision: item.prompt.revision,
            cue: Self.cueProfile,
            slots: slotRecords
        )
        results.append(SentenceResult(
            prompt: item.prompt,
            sentence: item.writtenSentence,
            kana: item.kanaSentence,
            misses: misses,
            hintsUsed: hintsUsed,
            cellCount: item.writable.count
        ))
        isSentenceComplete = true
        onSentenceCompleted?(record)
    }
}
