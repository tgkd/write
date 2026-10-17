import Foundation

struct RunContext: Equatable, Sendable {
    var sessionID: UUID?
    var origin: RunOrigin?
    var slot: Int?
}
