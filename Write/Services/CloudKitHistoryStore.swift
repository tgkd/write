import CloudKit
import Foundation

final class CloudKitHistoryStore: HistorySyncCloud {
    static let containerIdentifier = "iCloud.com.j.write"
    static let zoneName = "History"
    static let recordType = "PracticeRecord"
    static let payloadKey = "payload"
    static let completedAtKey = "completedAt"

    private let container: CKContainer

    init() {
        container = CKContainer(identifier: Self.containerIdentifier)
    }

    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    private static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    func accountAvailable() async throws -> Bool {
        do {
            return try await container.accountStatus() == .available
        } catch {
            throw Self.map(error)
        }
    }

    func ensureZone() async throws {
        do {
            _ = try await database.save(CKRecordZone(zoneID: Self.zoneID))
        } catch {
            throw Self.map(error)
        }
    }

    func save(_ uploads: [HistorySyncUpload]) async throws -> Set<UUID> {
        let zoneID = Self.zoneID
        let records = uploads.map { upload in
            let record = CKRecord(
                recordType: Self.recordType,
                recordID: CKRecord.ID(recordName: upload.id.uuidString, zoneID: zoneID)
            )
            record[Self.payloadKey] = upload.payload as NSData
            record[Self.completedAtKey] = upload.completedAt as NSDate
            return record
        }
        let collector = HistorySyncSaveCollector()
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.isAtomic = false
        operation.savePolicy = .ifServerRecordUnchanged
        operation.qualityOfService = .utility
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success:
                collector.markSaved(recordID.recordName)
            case .failure(let error):
                if (error as? CKError)?.code == .serverRecordChanged {
                    collector.markSaved(recordID.recordName)
                }
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: collector.savedIDs)
                case .failure(let error):
                    let mapped = Self.map(error)
                    if mapped == .transient, (error as? CKError)?.code == .partialFailure {
                        continuation.resume(returning: collector.savedIDs)
                    } else {
                        continuation.resume(throwing: mapped)
                    }
                }
            }
            database.add(operation)
        }
    }

    func fetchChanges(since token: Data?) async throws -> HistorySyncChanges {
        let zoneID = Self.zoneID
        let previous = token.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0)
        }
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: previous, resultsLimit: nil, desiredKeys: nil
        )
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: configuration]
        )
        operation.fetchAllChanges = true
        operation.qualityOfService = .utility
        let collector = HistorySyncFetchCollector()
        operation.recordWasChangedBlock = { _, result in
            switch result {
            case .success(let record):
                guard record.recordType == Self.recordType else {
                    return
                }
                collector.append(record[Self.payloadKey] as? Data)
            case .failure:
                collector.append(nil)
            }
        }
        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            collector.setToken(Self.archive(token))
        }
        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case .success(let fetched):
                collector.setToken(Self.archive(fetched.serverChangeToken))
            case .failure(let error):
                collector.fail(Self.map(error))
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    if let error = collector.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: collector.changes)
                    }
                case .failure(let error):
                    continuation.resume(throwing: collector.error ?? Self.map(error))
                }
            }
            database.add(operation)
        }
    }

    private static func archive(_ token: CKServerChangeToken?) -> Data? {
        guard let token else {
            return nil
        }
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    static func map(_ error: Error) -> HistorySyncError {
        guard let error = error as? CKError else {
            return .transient
        }
        if let seconds = error.retryAfterSeconds {
            return .retryAfter(seconds)
        }
        switch error.code {
        case .changeTokenExpired:
            return .tokenExpired
        case .zoneNotFound, .userDeletedZone:
            return .zoneMissing
        case .limitExceeded:
            return .limitExceeded
        case .notAuthenticated, .accountTemporarilyUnavailable, .managedAccountRestricted:
            return .accountUnavailable
        case .partialFailure:
            let inner = (error.partialErrorsByItemID ?? [:]).values.map(map)
            return HistorySyncError.mostSevere(inner)
        default:
            return .transient
        }
    }
}
