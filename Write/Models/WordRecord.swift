import Foundation

struct WordRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let promptID: String
    let startedAt: Date
    let completedAt: Date
    let misses: Int
    let hintsUsed: Int
    let slotCount: Int
    var sessionID: UUID?
    var promptRevision: String?
    var cue: String?
    var slots: [WordSlotRecord]?
}

extension WordRecord {
    var effectiveMisses: Int {
        guard let slots else {
            return misses
        }
        let disputed = slots.reduce(0) { $0 + ($1.record.evidence?.disputed ?? 0) }
        return max(0, misses - disputed)
    }
}
