import Combine
import Foundation

@MainActor
final class WritingSession: ObservableObject {
    struct Cell: Identifiable {
        let id: String
        let characterIndex: Int
        let character: Character
        let kanjiData: KanjiData?

        var isPunctuation: Bool { character.isPunctuation || character.isWhitespace }
    }

    struct Phrase: Identifiable {
        let id: String
        let tokenIndices: [Int]
        let text: String
        let reading: String
        let units: [Cell]

        var cells: [Cell] { units.filter { !$0.isPunctuation } }
        var writable: [Cell] { cells.filter { $0.kanjiData != nil } }
    }

    struct Item {
        let prompt: WordPrompt
        let sentence: String
        let kana: String
        let phrases: [Phrase]
    }

    struct SentenceResult {
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
    @Published private(set) var phraseIndex = 0
    @Published private(set) var cellIndex = 0
    @Published private(set) var activeMode: WritingMode
    @Published private(set) var slotState: PracticeState?
    @Published private(set) var isPhraseComplete = false
    @Published private(set) var isSentenceComplete = false
    @Published private(set) var isComplete = false
    @Published private(set) var results: [SentenceResult] = []
    @Published private(set) var completedCellIDs: Set<String> = []
    @Published private(set) var completedSentenceCount = 0
    @Published var requestedMode: WritingMode
    var validationConfig: ValidationConfig {
        didSet { slotState?.validationConfig = validationConfig }
    }
    var onSentenceCompleted: ((WordRecord) -> Void)?
    private var slotRecords: [Int: WordSlotRecord] = [:]

    init(prompts: [WordPrompt], mode: WritingMode = .free, config: ValidationConfig = .standard, lookup: (Character) -> KanjiData?) {
        activeMode = mode
        requestedMode = mode
        validationConfig = config
        items = prompts.enumerated().compactMap { promptIndex, prompt in
            guard let tokens = prompt.tokens,
                  let groups = prompt.presentation?.validatedGroups(tokenCount: tokens.count) else {
                return nil
            }
            var characterIndex = 0
            let phrases = groups.enumerated().map { groupIndex, indices in
                let text = indices.map { tokens[$0].surface }.joined()
                let units = text.map { character in
                    let cell = Cell(
                        id: "\(promptIndex).\(characterIndex)", characterIndex: characterIndex,
                        character: character,
                        kanjiData: lookup(character).flatMap { $0.strokes.isEmpty ? nil : $0 }
                    )
                    characterIndex += 1
                    return cell
                }
                return Phrase(
                    id: "\(promptIndex).phrase.\(groupIndex)", tokenIndices: indices, text: text,
                    reading: indices.map { tokens[$0].reading ?? tokens[$0].surface }.joined(), units: units
                )
            }
            guard phrases.flatMap(\.writable).isEmpty == false else {
                return nil
            }
            return Item(prompt: prompt, sentence: tokens.map(\.surface).joined(),
                        kana: tokens.map { $0.reading ?? $0.surface }.joined(), phrases: phrases)
        }
        if let first = items.firstIndex(where: { mode != .empty || $0.prompt.presentation?.allowsEmpty == true }) {
            promptIndex = first
            startPhrase()
        } else {
            isComplete = true
        }
    }

    var currentItem: Item? {
        guard !isComplete, items.indices.contains(promptIndex) else {
            return nil
        }
        return items[promptIndex]
    }

    var currentPhrase: Phrase? { currentItem?.phrases[phraseIndex] }
    var isLastPhrase: Bool { phraseIndex + 1 == currentItem?.phrases.count }
    var isLastPrompt: Bool { nextPromptIndex == nil }

    var sentenceNumber: Int {
        completedSentenceCount + (isSentenceComplete || isComplete ? 0 : 1)
    }

    var totalSentenceCount: Int {
        sentenceNumber + remainingPromptIndices.count
    }

    var endsBeforeQueuedEmpty: Bool {
        requestedMode == .empty && activeMode != .empty && remainingPromptIndices.isEmpty
    }

    var currentCell: Cell? {
        guard activeMode != .free, !isPhraseComplete, !isSentenceComplete,
              let phrase = currentPhrase, phrase.writable.indices.contains(cellIndex) else {
            return nil
        }
        return phrase.writable[cellIndex]
    }

    private var remainingPromptIndices: [Int] {
        guard !isComplete else {
            return []
        }
        return items.indices.filter { $0 > promptIndex && (requestedMode != .empty || items[$0].prompt.presentation?.allowsEmpty == true) }
    }

    private var nextPromptIndex: Int? { remainingPromptIndices.first }

    func advance() {
        guard let item = currentItem else {
            return
        }
        if isSentenceComplete {
            guard let next = nextPromptIndex else {
                isComplete = true
                slotState = nil
                return
            }
            promptIndex = next
            phraseIndex = 0
            activeMode = requestedMode
            slotRecords = [:]
            completedCellIDs = []
            isSentenceComplete = false
            startPhrase()
        } else if activeMode == .free || isPhraseComplete {
            if phraseIndex + 1 < item.phrases.count {
                phraseIndex += 1
                startPhrase()
            } else {
                finishSentence()
            }
        }
    }

    func restartPhrase() {
        guard !isSentenceComplete, let phrase = currentPhrase else {
            return
        }
        if phraseIndex == 0, requestedMode != .empty || currentItem?.prompt.presentation?.allowsEmpty == true {
            activeMode = requestedMode
        }
        for cell in phrase.units {
            slotRecords[cell.characterIndex] = nil
            completedCellIDs.remove(cell.id)
        }
        startPhrase()
    }

    private func startPhrase() {
        cellIndex = 0
        isPhraseComplete = false
        slotState = makeSlotState()
        if activeMode != .free && currentPhrase?.writable.isEmpty == true {
            isPhraseComplete = true
            if isLastPhrase {
                finishSentence()
            }
        }
    }

    private func makeSlotState() -> PracticeState? {
        guard let cell = currentCell, let data = cell.kanjiData else {
            return nil
        }
        let state = PracticeState(kanjiData: data, mode: .trace, isRecall: activeMode == .empty,
                                  config: validationConfig,
                                  context: RunContext(sessionID: sessionID, origin: nil, slot: promptIndex))
        state.onRunCompleted = { [weak self, weak state] record in
            guard let self, let state, state === self.slotState, let current = self.currentCell else {
                return
            }
            self.slotRecords[current.characterIndex] = WordSlotRecord(segmentIndex: current.characterIndex, record: record)
            self.completedCellIDs.insert(current.id)
            self.cellIndex += 1
            if self.cellIndex >= (self.currentPhrase?.writable.count ?? 0) {
                self.slotState = nil
                self.isPhraseComplete = true
                if self.isLastPhrase {
                    self.finishSentence()
                }
            } else {
                self.slotState = self.makeSlotState()
            }
        }
        return state
    }

    private func finishSentence() {
        guard !isSentenceComplete, let item = currentItem else {
            return
        }
        isSentenceComplete = true
        completedSentenceCount += 1
        slotState = nil
        guard activeMode != .free else {
            return
        }
        let slots = slotRecords.keys.sorted().compactMap { slotRecords[$0] }
        let records = slots.map(\.record)
        let misses = records.reduce(0) { $0 + $1.misses }
        let hints = records.filter(\.revealed).count
        let completedAt = records.last?.completedAt ?? Date()
        let record = WordRecord(
            id: UUID(), promptID: item.prompt.id, startedAt: records.first?.startedAt ?? completedAt,
            completedAt: completedAt, misses: misses, hintsUsed: hints, slotCount: slots.count,
            sessionID: sessionID, promptRevision: item.prompt.revision,
            cue: "kana-sentence+en-translation/phrases-v1/\(activeMode.rawValue)", slots: slots
        )
        results.append(SentenceResult(prompt: item.prompt, sentence: item.sentence, kana: item.kana,
                                      misses: misses, hintsUsed: hints, cellCount: slots.count))
        onSentenceCompleted?(record)
    }
}
