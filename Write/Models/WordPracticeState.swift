import Combine
import Foundation

@MainActor
final class WordPracticeState: ObservableObject {
    static let cueProfile = "kana-sentence+en-gloss"

    struct Slot: Equatable {
        let segmentIndex: Int
        let kanjiData: KanjiData
    }

    struct Item: Equatable {
        let prompt: WordPrompt
        let slots: [Slot]
    }

    struct WordResult: Equatable {
        let prompt: WordPrompt
        let misses: Int
        let hintsUsed: Int
        let slotCount: Int
    }

    let sessionID = UUID()
    let items: [Item]
    @Published private(set) var promptIndex = 0
    @Published private(set) var slotIndex = 0
    @Published private(set) var slotState: PracticeState?
    @Published private(set) var isWordComplete = false
    @Published private(set) var isSessionComplete: Bool
    @Published private(set) var results: [WordResult] = []

    var validationConfig: ValidationConfig {
        didSet {
            slotState?.validationConfig = validationConfig
        }
    }

    var onWordCompleted: ((WordRecord) -> Void)?

    private(set) var slotRun = 0
    private var slotRecords: [WordSlotRecord] = []

    init(prompts: [WordPrompt], lookup: (Character) -> KanjiData?, config: ValidationConfig = .standard) {
        items = prompts.compactMap { prompt in
            WordPracticeState.item(for: prompt, lookup: lookup)
        }
        validationConfig = config
        isSessionComplete = items.isEmpty
        slotState = makeSlotState()
    }

    convenience init(prompts: [WordPrompt], dataStore: KanjiDataStore, config: ValidationConfig = .standard) {
        self.init(prompts: prompts, lookup: { dataStore.lookup(character: $0) }, config: config)
    }

    private static func item(for prompt: WordPrompt, lookup: (Character) -> KanjiData?) -> Item? {
        var slots: [Slot] = []
        for (index, segment) in prompt.segments.enumerated() where segment.isKanji {
            guard let character = segment.kanjiCharacter,
                  let kanjiData = lookup(character),
                  !kanjiData.strokes.isEmpty else {
                return nil
            }
            slots.append(Slot(segmentIndex: index, kanjiData: kanjiData))
        }
        guard !slots.isEmpty else {
            return nil
        }
        return Item(prompt: prompt, slots: slots)
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

    var currentSlot: Slot? {
        guard let item = currentItem, item.slots.indices.contains(slotIndex) else {
            return nil
        }
        return item.slots[slotIndex]
    }

    var currentSlotID: String? {
        guard let prompt = currentPrompt, let slot = currentSlot else {
            return nil
        }
        return prompt.slotID(segmentIndex: slot.segmentIndex)
    }

    var currentSegmentIndex: Int? {
        guard !isWordComplete else {
            return nil
        }
        return currentSlot?.segmentIndex
    }

    var completedSegmentIndices: Set<Int> {
        guard let item = currentItem else {
            return []
        }
        let count = isWordComplete ? item.slots.count : slotIndex
        return Set(item.slots.prefix(count).map(\.segmentIndex))
    }

    var progress: (current: Int, total: Int) {
        (min(promptIndex + 1, items.count), items.count)
    }

    var isLastWord: Bool {
        promptIndex + 1 >= items.count
    }

    var wordsNeedingHints: Int {
        results.filter { $0.hintsUsed > 0 }.count
    }

    func advanceWord() {
        guard isWordComplete else {
            return
        }
        guard promptIndex + 1 < items.count else {
            isSessionComplete = true
            slotState = nil
            return
        }
        promptIndex += 1
        startWord()
    }

    func resetWord() {
        guard !isWordComplete, currentItem != nil else {
            return
        }
        startWord()
    }

    private func startWord() {
        slotIndex = 0
        slotRecords = []
        isWordComplete = false
        slotState = makeSlotState()
    }

    private func makeSlotState() -> PracticeState? {
        guard let slot = currentSlot else {
            return nil
        }
        let state = PracticeState(
            kanjiData: slot.kanjiData,
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
        guard state === slotState, !isWordComplete, let item = currentItem, let slot = currentSlot else {
            return
        }
        slotRecords.append(WordSlotRecord(segmentIndex: slot.segmentIndex, record: record))
        guard slotIndex + 1 >= item.slots.count else {
            slotIndex += 1
            slotState = makeSlotState()
            return
        }
        finishWord(item)
    }

    private func finishWord(_ item: Item) {
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
            slotCount: item.slots.count,
            sessionID: sessionID,
            promptRevision: item.prompt.revision,
            cue: Self.cueProfile,
            slots: slotRecords
        )
        results.append(WordResult(
            prompt: item.prompt,
            misses: misses,
            hintsUsed: hintsUsed,
            slotCount: item.slots.count
        ))
        isWordComplete = true
        onWordCompleted?(record)
    }
}
