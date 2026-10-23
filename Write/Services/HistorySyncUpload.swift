import Foundation

struct HistorySyncUpload: Sendable, Equatable {
    let id: UUID
    let payload: Data
    let completedAt: Date
}
