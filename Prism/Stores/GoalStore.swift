import Combine
import Foundation

@MainActor
final class GoalStore: ObservableObject {
    @Published var careerGoal: String {
        didSet {
            save(careerGoal, forKey: careerGoalKey)
            markUpdated()
        }
    }

    @Published var healthGoal: String {
        didSet {
            save(healthGoal, forKey: healthGoalKey)
            markUpdated()
        }
    }

    @Published var socialGoal: String {
        didSet {
            save(socialGoal, forKey: socialGoalKey)
            markUpdated()
        }
    }

    private let userDefaults: UserDefaults
    private let careerGoalKey: String
    private let healthGoalKey: String
    private let socialGoalKey: String
    private let updatedAtKey: String
    private let syncService: FirebaseBackupService?
    private let authSession: AuthSessionStore?
    private var updatedAt: Date
    private var isApplyingRemoteSnapshot = false

    init(
        userDefaults: UserDefaults = .standard,
        careerGoalKey: String = "orbit.goals.career.v1",
        healthGoalKey: String = "orbit.goals.health.v1",
        socialGoalKey: String = "orbit.goals.social.v1",
        updatedAtKey: String = "prism.goals.updatedAt.v1",
        syncService: FirebaseBackupService? = nil,
        authSession: AuthSessionStore? = nil
    ) {
        self.userDefaults = userDefaults
        self.careerGoalKey = careerGoalKey
        self.healthGoalKey = healthGoalKey
        self.socialGoalKey = socialGoalKey
        self.updatedAtKey = updatedAtKey
        self.syncService = syncService
        self.authSession = authSession
        self.updatedAt = userDefaults.object(forKey: updatedAtKey) as? Date ?? .distantPast
        self.careerGoal = userDefaults.string(forKey: careerGoalKey) ?? ""
        self.healthGoal = userDefaults.string(forKey: healthGoalKey) ?? ""
        self.socialGoal = userDefaults.string(forKey: socialGoalKey) ?? ""
    }

    private func save(_ value: String, forKey key: String) {
        userDefaults.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: key)
    }

    private func markUpdated() {
        guard !isApplyingRemoteSnapshot else { return }
        updatedAt = .now
        userDefaults.set(updatedAt, forKey: updatedAtKey)
    }

    func synchronizeWithCloud() async {
        guard
            let syncService,
            let userID = authSession?.currentUser?.uid
        else {
            return
        }

        do {
            let merged = try await syncService.synchronizeGoals(snapshot(), userID: userID)
            apply(merged)
        } catch {
            print("Error:", error)
        }
    }

    func flushCloudSyncNow() async {
        guard
            let syncService,
            let userID = authSession?.currentUser?.uid
        else {
            return
        }

        do {
            try await syncService.pushGoals(snapshot(), userID: userID)
        } catch {
            print("Error:", error)
        }
    }

    private func snapshot() -> GoalSnapshot {
        GoalSnapshot(
            careerGoal: careerGoal,
            healthGoal: healthGoal,
            socialGoal: socialGoal,
            updatedAt: updatedAt
        )
    }

    private func apply(_ snapshot: GoalSnapshot) {
        isApplyingRemoteSnapshot = true
        careerGoal = snapshot.careerGoal
        healthGoal = snapshot.healthGoal
        socialGoal = snapshot.socialGoal
        updatedAt = snapshot.updatedAt
        userDefaults.set(updatedAt, forKey: updatedAtKey)
        isApplyingRemoteSnapshot = false
    }
}
