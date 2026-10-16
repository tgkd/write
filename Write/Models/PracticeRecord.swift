import Foundation

struct PracticeRecord: Codable, Equatable, Identifiable, Sendable {
    static let recallMode = "study"

    let id: UUID
    let codePoint: String
    let mode: String
    let revealed: Bool
    let exposed: Bool
    let misses: Int
    let startedAt: Date
    let completedAt: Date
    let leniency: Double
    var strictness: GradingStrictness?
    var gradingVersion: Int?
    var evidence: MissEvidence?

    var isRecall: Bool {
        mode == Self.recallMode
    }
}
