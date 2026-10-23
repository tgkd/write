import Foundation

struct HistorySyncChanges: Sendable, Equatable {
    let payloads: [Data?]
    let token: Data?
}
