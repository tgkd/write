import Foundation

struct SessionRoute: Hashable {
    let codePoints: [String]
}

@MainActor
final class SessionState: ObservableObject {

    struct KanjiResult {
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

    init(kanjiQueue: [KanjiData]) {
        self.kanjiQueue = kanjiQueue
    }

    func recordResult(attemptCount: Int) {
        guard currentIndex < kanjiQueue.count else { return }
        results.append(KanjiResult(
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
