import FirebaseFirestore
import Foundation

actor FirebaseBackupService {
    private enum Constants {
        static let usersCollection = "users"
        static let checkInsCollection = "checkIns"
        static let metadataCollection = "metadata"
        static let goalsDocument = "goals"
        static let date = "date"
        static let updatedAt = "updatedAt"
        static let career = "career"
        static let health = "health"
        static let social = "social"
        static let careerNote = "careerNote"
        static let healthNote = "healthNote"
        static let socialNote = "socialNote"
        static let id = "id"
        static let careerGoal = "careerGoal"
        static let healthGoal = "healthGoal"
        static let socialGoal = "socialGoal"
        static let careerGoalLabel = "Career Goal"
        static let healthGoalLabel = "Health Goal"
        static let socialGoalLabel = "Social Goal"
    }

    private let database: Firestore
    private let calendar: Calendar

    init(database: Firestore = Firestore.firestore(), calendar: Calendar = .current) {
        self.database = database
        self.calendar = calendar
    }

    func synchronizeCheckIns(_ localCheckIns: [DailyCheckIn], userID: String) async throws -> [DailyCheckIn] {
        let remoteCheckIns = try await fetchCheckIns(userID: userID)
        let merged = merge(local: localCheckIns, remote: remoteCheckIns)
        try await saveCheckIns(merged, userID: userID)
        return merged
    }

    func pushCheckIns(_ checkIns: [DailyCheckIn], userID: String) async throws {
        try await saveCheckIns(checkIns, userID: userID)
    }

    func synchronizeGoals(_ localGoals: GoalSnapshot, userID: String) async throws -> GoalSnapshot {
        let remoteGoals = try await fetchGoals(userID: userID)
        let merged = remoteGoals.map { $0.updatedAt > localGoals.updatedAt ? $0 : localGoals } ?? localGoals
        try await saveGoals(merged, userID: userID)
        return merged
    }

    func pushGoals(_ goals: GoalSnapshot, userID: String) async throws {
        try await saveGoals(goals, userID: userID)
    }

    private func fetchCheckIns(userID: String) async throws -> [DailyCheckIn] {
        let snapshot = try await checkInsCollection(userID: userID).getDocuments()

        return snapshot.documents.compactMap { document in
            guard
                let idString = document[Constants.id] as? String,
                let id = UUID(uuidString: idString),
                let date = (document[Constants.date] as? Timestamp)?.dateValue(),
                let updatedAt = (document[Constants.updatedAt] as? Timestamp)?.dateValue(),
                let career = document[Constants.career] as? Int,
                let health = document[Constants.health] as? Int,
                let social = document[Constants.social] as? Int
            else {
                return nil
            }

            return DailyCheckIn(
                id: id,
                date: calendar.startOfDay(for: date),
                updatedAt: updatedAt,
                career: career,
                health: health,
                social: social,
                careerNote: document[Constants.careerNote] as? String ?? "",
                healthNote: document[Constants.healthNote] as? String ?? "",
                socialNote: document[Constants.socialNote] as? String ?? ""
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func saveCheckIns(_ checkIns: [DailyCheckIn], userID: String) async throws {
        let batch = database.batch()
        let collection = checkInsCollection(userID: userID)

        for item in checkIns {
            let document = collection.document(checkInDocumentID(for: item.date))
            let safeDate = item.date < Date(timeIntervalSince1970: 0) ? Date() : item.date
            let timestamp = Timestamp(date: safeDate)
            let safeUpdatedAt = item.updatedAt < Date(timeIntervalSince1970: 0) ? Date() : item.updatedAt
            let updatedAtTimestamp = Timestamp(date: safeUpdatedAt)
            batch.setData([
                Constants.id: item.id.uuidString,
                Constants.date: timestamp,
                Constants.updatedAt: updatedAtTimestamp,
                Constants.career: item.career,
                Constants.health: item.health,
                Constants.social: item.social,
                Constants.careerNote: item.careerNote,
                Constants.healthNote: item.healthNote,
                Constants.socialNote: item.socialNote,
            ], forDocument: document, merge: true)
        }

        try await batch.commit()
    }

    private func fetchGoals(userID: String) async throws -> GoalSnapshot? {
        let snapshot = try await goalsDocument(userID: userID).getDocument()
        guard
            let data = snapshot.data(),
            let updatedAt = (data[Constants.updatedAt] as? Timestamp)?.dateValue()
        else {
            return nil
        }

        return GoalSnapshot(
            careerGoal: data[Constants.careerGoalLabel] as? String ?? data[Constants.careerGoal] as? String ?? "",
            healthGoal: data[Constants.healthGoalLabel] as? String ?? data[Constants.healthGoal] as? String ?? "",
            socialGoal: data[Constants.socialGoalLabel] as? String ?? data[Constants.socialGoal] as? String ?? "",
            updatedAt: updatedAt
        )
    }

    private func saveGoals(_ goals: GoalSnapshot, userID: String) async throws {
        let safeDate = goals.updatedAt < Date(timeIntervalSince1970: 0) ? Date() : goals.updatedAt
        let timestamp = Timestamp(date: safeDate)
        try await goalsDocument(userID: userID).setData([
            Constants.careerGoalLabel: goals.careerGoal,
            Constants.healthGoalLabel: goals.healthGoal,
            Constants.socialGoalLabel: goals.socialGoal,
            Constants.careerGoal: goals.careerGoal,
            Constants.healthGoal: goals.healthGoal,
            Constants.socialGoal: goals.socialGoal,
            Constants.updatedAt: timestamp,
        ], merge: true)
    }

    private func merge(local: [DailyCheckIn], remote: [DailyCheckIn]) -> [DailyCheckIn] {
        var mergedByDay: [Date: DailyCheckIn] = [:]

        for item in local + remote {
            let day = calendar.startOfDay(for: item.date)
            if let existing = mergedByDay[day] {
                mergedByDay[day] = item.updatedAt >= existing.updatedAt ? item : existing
            } else {
                mergedByDay[day] = item
            }
        }

        return mergedByDay.values.sorted { $0.date < $1.date }
    }

    private func checkInsCollection(userID: String) -> CollectionReference {
        database
            .collection(Constants.usersCollection)
            .document(userID)
            .collection(Constants.checkInsCollection)
    }

    private func goalsDocument(userID: String) -> DocumentReference {
        database
            .collection(Constants.usersCollection)
            .document(userID)
            .collection(Constants.metadataCollection)
            .document(Constants.goalsDocument)
    }

    private func checkInDocumentID(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
