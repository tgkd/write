import Foundation

struct WordRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let promptID: String
    let startedAt: Date
    let completedAt: Date
    let misses: Int
    let hintsUsed: Int
    let slotCount: Int
}
