import Foundation

enum PracticeQueue {
    static func route(
        focus: PracticeFocus,
        practicePool: [String],
        reviewPool: [String],
        records: [PracticeRecord],
        count: Int
    ) -> SessionRoute {
        var generator = SystemRandomNumberGenerator()
        return route(
            focus: focus,
            practicePool: practicePool,
            reviewPool: reviewPool,
            records: records,
            count: count,
            using: &generator
        )
    }

    static func route<Generator: RandomNumberGenerator>(
        focus: PracticeFocus,
        practicePool: [String],
        reviewPool: [String],
        records: [PracticeRecord],
        count: Int,
        using generator: inout Generator
    ) -> SessionRoute {
        switch focus {
        case .new:
            let codePoints = newCodePoints(pool: practicePool, records: records, count: count, using: &generator)
            return SessionRoute(codePoints: codePoints, kind: .practice, origin: .randomSession)
        case .review:
            let codePoints = reviewCodePoints(pool: reviewPool, records: records, count: count, using: &generator)
            let hasMissed = !missedCodePoints(pool: reviewPool, records: records).isEmpty
            return SessionRoute(codePoints: codePoints, kind: .recall, origin: hasMissed ? .reviewSession : .randomSession)
        }
    }

    static func newCodePoints<Generator: RandomNumberGenerator>(
        pool: [String],
        records: [PracticeRecord],
        count: Int,
        using generator: inout Generator
    ) -> [String] {
        Array(pool.shuffled(using: &generator).prefix(count))
    }

    static func reviewCodePoints<Generator: RandomNumberGenerator>(
        pool: [String],
        records: [PracticeRecord],
        count: Int,
        using generator: inout Generator
    ) -> [String] {
        Array(pool.shuffled(using: &generator).prefix(count))
    }

    static func missedCodePoints(pool: [String], records: [PracticeRecord]) -> [String] {
        let allowed = Set(pool)
        return PracticeStats.reviewItems(from: records).map(\.codePoint).filter(allowed.contains)
    }
}
