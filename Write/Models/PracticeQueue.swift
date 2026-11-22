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
        guard count > 0 else { return [] }
        let practised = Set(records.map(\.codePoint))
        let fresh = pool.filter { !practised.contains($0) }.shuffled(using: &generator)
        guard fresh.count < count else { return Array(fresh.prefix(count)) }
        let seen = pool.filter(practised.contains).shuffled(using: &generator)
        return uniquePrefix(fresh + seen, count: count)
    }

    static func reviewCodePoints<Generator: RandomNumberGenerator>(
        pool: [String],
        records: [PracticeRecord],
        count: Int,
        using generator: inout Generator
    ) -> [String] {
        guard count > 0 else { return [] }
        let latest = latestCompletion(in: records)
        let missed = missedCodePoints(pool: pool, records: records)
        let missedSet = Set(missed)
        let seen = pool
            .filter { !missedSet.contains($0) }
            .compactMap { codePoint in latest[codePoint].map { (date: $0, codePoint: codePoint) } }
            .sorted { ($0.date, $0.codePoint) < ($1.date, $1.codePoint) }
            .map(\.codePoint)
        let queued = missed + seen
        guard queued.count < count else { return uniquePrefix(queued, count: count) }
        let fresh = pool.filter { latest[$0] == nil }.shuffled(using: &generator)
        return uniquePrefix(queued + fresh, count: count)
    }

    private static func latestCompletion(in records: [PracticeRecord]) -> [String: Date] {
        records.reduce(into: [:]) { latest, record in
            latest[record.codePoint] = max(latest[record.codePoint] ?? record.completedAt, record.completedAt)
        }
    }

    private static func uniquePrefix(_ codePoints: [String], count: Int) -> [String] {
        var seen = Set<String>()
        return Array(codePoints.filter { seen.insert($0).inserted }.prefix(count))
    }

    static func missedCodePoints(pool: [String], records: [PracticeRecord]) -> [String] {
        let allowed = Set(pool)
        return PracticeStats.reviewItems(from: records).map(\.codePoint).filter(allowed.contains)
    }
}
