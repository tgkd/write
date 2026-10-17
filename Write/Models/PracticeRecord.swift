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
    var strictness: String?
    var gradingVersion: Int?
    var evidence: MissEvidence?
    var sessionID: UUID?
    var slot: Int?
    var origin: String?
    var hint: String?
    var undos: Int?
    var input: String?
    var canvasWidth: Double?
    var canvasHeight: Double?
    var idiom: String?
    var appVersion: String?
    var shownAt: Date?
    var firstTouchAt: Date?
    var interrupted: Bool?
    var configChanged: Bool?
    var strokes: [StrokeStat]?

    var isRecall: Bool {
        mode == Self.recallMode
    }
}
