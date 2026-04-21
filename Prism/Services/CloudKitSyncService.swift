import CloudKit
import Foundation

actor CloudKitSyncService {
    private enum Constants {
        static let containerIdentifier = "iCloud.com.tanagarn.Prism"
        static let recordType = "DailyCheckIn"
        static let date = "date"
        static let updatedAt = "updatedAt"
        static let career = "career"
        static let health = "health"
        static let social = "social"
        static let careerNote = "careerNote"
        static let healthNote = "healthNote"
        static let socialNote = "socialNote"
    }

    private let container: CKContainer
    private let database: CKDatabase
    private let calendar: Calendar

    init(
        container: CKContainer = CKContainer(identifier: Constants.containerIdentifier),
        calendar: Calendar = .current
    ) {
        self.container = container
        self.database = container.privateCloudDatabase
        self.calendar = calendar
    }

    func isAvailable() async -> Bool {
        do {
            let status = try await accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    func fetchAllCheckIns() async throws -> [DailyCheckIn] {
        guard try await accountStatus() == .available else {
            return []
        }

        let query = CKQuery(recordType: Constants.recordType, predicate: NSPredicate(value: true))
        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let batch = try await fetchBatch(query: query, cursor: cursor)
            records.append(contentsOf: batch.records)
            cursor = batch.cursor
        } while cursor != nil

        return try records
            .compactMap { try Self.makeCheckIn(from: $0, calendar: calendar) }
            .sorted { $0.date < $1.date }
    }

    func save(_ checkIns: [DailyCheckIn]) async throws {
        guard try await accountStatus() == .available else {
            return
        }

        let records = checkIns.map(makeRecord)

        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.isAtomic = false
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func fetchBatch(
        query: CKQuery,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }

            var records: [CKRecord] = []
            operation.resultsLimit = 200
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    records.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    continuation.resume(returning: (records, nextCursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func makeRecord(from checkIn: DailyCheckIn) -> CKRecord {
        let recordID = CKRecord.ID(recordName: checkIn.id.uuidString)
        let record = CKRecord(recordType: Constants.recordType, recordID: recordID)

        record[Constants.date] = checkIn.date as NSDate
        record[Constants.updatedAt] = checkIn.updatedAt as NSDate
        record[Constants.career] = checkIn.career as NSNumber
        record[Constants.health] = checkIn.health as NSNumber
        record[Constants.social] = checkIn.social as NSNumber
        record[Constants.careerNote] = checkIn.careerNote as NSString
        record[Constants.healthNote] = checkIn.healthNote as NSString
        record[Constants.socialNote] = checkIn.socialNote as NSString

        return record
    }

    private static func makeCheckIn(from record: CKRecord, calendar: Calendar) throws -> DailyCheckIn {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let date = record[Constants.date] as? Date,
            let updatedAt = record[Constants.updatedAt] as? Date,
            let career = record[Constants.career] as? NSNumber,
            let health = record[Constants.health] as? NSNumber,
            let social = record[Constants.social] as? NSNumber
        else {
            throw CloudKitSyncError.invalidRecord
        }

        return DailyCheckIn(
            id: id,
            date: calendar.startOfDay(for: date),
            updatedAt: updatedAt,
            career: career.intValue,
            health: health.intValue,
            social: social.intValue,
            careerNote: record[Constants.careerNote] as? String ?? "",
            healthNote: record[Constants.healthNote] as? String ?? "",
            socialNote: record[Constants.socialNote] as? String ?? ""
        )
    }
}

enum CloudKitSyncError: Error {
    case invalidRecord
}
