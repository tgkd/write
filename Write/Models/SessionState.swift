import Foundation

enum SessionKind: Hashable, Sendable {
    case practice
    case recall
}

struct SessionRoute: Hashable {
    let codePoints: [String]
    var kind: SessionKind = .practice

    static func review(_ items: [PracticeStats.ReviewItem], count: Int) -> SessionRoute {
        SessionRoute(codePoints: items.prefix(count).map(\.codePoint), kind: .recall)
    }
}

@MainActor
final class SessionState: ObservableObject {

    struct KanjiResult {
        let slot: Int
        let kanjiData: KanjiData
        let attemptCount: Int
        let usedHint: Bool
    }

    let kanjiQueue: [KanjiData]
    let kind: SessionKind
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var results: [KanjiResult] = []
    @Published private(set) var isSessionComplete: Bool

    var currentKanji: KanjiData? {
        guard currentIndex < kanjiQueue.count else { return nil }
        return kanjiQueue[currentIndex]
    }

    var progress: (current: Int, total: Int) {
        (currentIndex + 1, kanjiQueue.count)
    }

    init(kanjiQueue: [KanjiData], kind: SessionKind = .practice) {
        self.kanjiQueue = kanjiQueue
        self.kind = kind
        self.isSessionComplete = kanjiQueue.isEmpty
    }

    func recordResult(attemptCount: Int, usedHint: Bool = false) {
        guard currentIndex < kanjiQueue.count else { return }
        results.removeAll { $0.slot == currentIndex }
        results.append(KanjiResult(
            slot: currentIndex,
            kanjiData: kanjiQueue[currentIndex],
            attemptCount: attemptCount,
            usedHint: usedHint
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
