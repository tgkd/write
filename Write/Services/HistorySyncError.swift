import Foundation

enum HistorySyncError: Error, Equatable {
    case accountUnavailable
    case zoneMissing
    case tokenExpired
    case limitExceeded
    case retryAfter(TimeInterval)
    case transient

    private var severity: Int {
        switch self {
        case .zoneMissing:
            return 5
        case .accountUnavailable:
            return 4
        case .retryAfter:
            return 3
        case .limitExceeded:
            return 2
        case .tokenExpired:
            return 1
        case .transient:
            return 0
        }
    }

    static func mostSevere(_ errors: [HistorySyncError]) -> HistorySyncError {
        errors.max { $0.severity < $1.severity } ?? .transient
    }
}
