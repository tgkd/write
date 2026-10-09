import Foundation

struct SessionRoute: Hashable {
    let codePoints: [String]
    var mode: PracticeMode = .trace
}

@MainActor
final class SessionState: ObservableObject {

    struct KanjiResult {
        let slot: Int
        let kanjiData: KanjiData
        let attemptCount: Int
    }

    let kanjiQueue: [KanjiData]
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var results: [KanjiResult] = []
    @Published private(set) var isSessionComplete: Bool = false
    @Published var mode: PracticeMode = .trace

    var currentKanji: KanjiData? {
        guard currentIndex < kanjiQueue.count else { return nil }
        return kanjiQueue[currentIndex]
    }

    var progress: (current: Int, total: Int) {
        (currentIndex + 1, kanjiQueue.count)
    }

    init(kanjiQueue: [KanjiData], mode: PracticeMode = .trace) {
        self.kanjiQueue = kanjiQueue
        self.mode = mode
    }

    func recordResult(attemptCount: Int) {
        guard currentIndex < kanjiQueue.count else { return }
        results.removeAll { $0.slot == currentIndex }
        results.append(KanjiResult(
            slot: currentIndex,
            kanjiData: kanjiQueue[currentIndex],
            attemptCount: attemptCount
        ))
    }

    func advance() {
        guard currentIndex + 1 < kanjiQueue.count else {
            isSessionComplete = true
            return
        }
        currentIndex += 1
    }
}
