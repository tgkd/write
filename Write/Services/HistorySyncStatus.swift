import Foundation

enum HistorySyncStatus: Equatable {
    case notSynced
    case syncing
    case synced(Date)
    case accountUnavailable
}
